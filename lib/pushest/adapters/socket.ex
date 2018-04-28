defmodule Pushest.Adapters.Socket do
  @moduledoc ~S"""
  GenServer responsible for communication with Pusher via WebSockets.
  This module is meant to be used internally as part of the Pushest application.
  """

  require Logger

  use GenServer

  alias Pushest.Socket.Utils
  alias Pushest.Socket.Data.{State, Frame, Url, Presence, SocketInfo}
  alias Pushest.Data.Options

  @behaviour Pushest.Adapter

  @client Pushest.Client.for_env()

  ## ==========================================================================
  ## Client
  ## ==========================================================================

  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      init_state(opts),
      name: __MODULE__
    )
  end

  def call(command) do
    GenServer.call(__MODULE__, command)
  end

  def cast(command) do
    GenServer.cast(__MODULE__, command)
  end

  ## ==========================================================================
  ## Server
  ## ==========================================================================

  def init(state = %State{url: %Url{domain: domain, path: path, port: port}}) do
    {:ok, conn_pid} = @client.open(domain, port)
    Process.monitor(conn_pid)

    case @client.await_up(conn_pid) do
      {:ok, :http} ->
        @client.ws_upgrade(conn_pid, path)
        {:ok, %{state | conn_pid: conn_pid}}

      {:error, msg} ->
        {:stop, "Socket | Connection init error #{inspect(msg)}"}
    end
  end

  @doc ~S"""
  Async server-side callback handling un/subscriptions and triggers to a Pusher channel.
  """
  @spec handle_cast({atom, String.t(), map}, %State{}) :: {:noreply, %State{}}
  def handle_cast({:subscribe, channel = "presence-" <> _rest, user_data}, state) do
    case Utils.validate_user_data(user_data) do
      {:ok, user_data} ->
        do_subscribe(channel, user_data, state)

      {:error, _} ->
        Logger.error(
          "Socket | #{channel} is a presence channel and subscription must include channel_data"
        )
    end

    {:noreply, %{state | presence: %{state.presence | me: user_data}}}
  end

  def handle_cast({:subscribe, channel, user_data}, state) do
    do_subscribe(channel, user_data, state)
    {:noreply, state}
  end

  def handle_cast({:unsubscribe, channel}, state = %State{conn_pid: conn_pid, channels: channels}) do
    frame = channel |> Frame.unsubscribe() |> Frame.encode!()

    @client.ws_send(conn_pid, {:text, frame})

    {:noreply, %{state | channels: List.delete(channels, channel)}}
  end

  def handle_cast({:trigger, channel, event, data}, state = %State{conn_pid: conn_pid}) do
    frame =
      channel
      |> Frame.event(event, data)
      |> Frame.encode!()

    @client.ws_send(conn_pid, {:text, frame})

    {:noreply, state}
  end

  @doc ~S"""
  Sync server-side callback returning list of subscribed channels.
  """
  @spec handle_call(:channels | :presence, {pid, term}, %State{}) ::
          {:reply, list | %Presence{}, %State{}}
  def handle_call(:channels, _from, state = %State{channels: channels}) do
    {:reply, channels, state}
  end

  @doc ~S"""
  Sync server-side callback returning current presence information.
  Contains IDs of all the subscribed users and optional informations about them.
  """
  def handle_call(:presence, _from, state = %State{presence: presence}) do
    {:reply, presence, state}
  end

  @spec handle_info(term, %State{}) :: {:noreply, %State{}}
  def handle_info({:gun_ws_upgrade, _conn_pid, :ok, _headers}, state) do
    {:noreply, state}
  end

  @doc ~S"""
  Handles varios Pusher events, updates state and tries to call user-defined callbacks.
  """
  def handle_info(
        {:gun_ws, _conn_pid, {:text, raw_frame}},
        state = %State{
          channels: channels,
          presence: presence,
          callback_module: callback_module,
          init_channels: init_channels
        }
      ) do
    frame = Frame.decode!(raw_frame)

    case frame.event do
      "pusher:connection_established" ->
        Logger.debug("Socket | pusher:connection_established")

        do_init_channels(init_channels)

        {:noreply, %{state | socket_info: SocketInfo.decode(frame.data)}}

      "pusher_internal:subscription_succeeded" ->
        Logger.debug("Socket | pusher_internal:subscription_succeeded")
        presence = Presence.merge(presence, frame.data["presence"])
        {:noreply, %{state | channels: [frame.channel | channels], presence: presence}}

      "pusher_internal:member_added" ->
        Logger.debug("Socket | pusher_internal:member_added")
        {:noreply, %{state | presence: Presence.add_member(presence, frame.data)}}

      "pusher_internal:member_removed" ->
        Logger.debug("Socket | pusher_internal:member_removed")
        {:noreply, %{state | presence: Presence.remove_member(presence, frame.data)}}

      "pusher:error" ->
        message = Map.get(frame.data, "message")
        Logger.error(fn -> "Socket | pusher:error #{inspect(message)}" end)

        Pushest.Utils.try_callback(callback_module, :handle_event, [{:error, message}, frame])
        {:noreply, state}

      _ ->
        Pushest.Utils.try_callback(callback_module, :handle_event, [
          {:ok, frame.channel, frame.event},
          frame
        ])

        {:noreply, state}
    end
  end

  def handle_info(
        {:gun_up, _pid, _protocol},
        state = %State{conn_pid: conn_pid, url: %Url{path: path}}
      ) do
    Logger.debug(fn -> "Socket | :gun_up | upgrading to ws" end)
    @client.ws_upgrade(conn_pid, path)
    {:noreply, state}
  end

  def handle_info(params, state) do
    Logger.debug(fn -> "Socket | #{inspect(params)}" end)
    {:noreply, state}
  end

  ## ==========================================================================
  ## Private
  ## ==========================================================================

  @spec do_subscribe(String.t(), map, %State{}) :: term
  defp do_subscribe(channel, user_data, state = %State{conn_pid: conn_pid}) do
    auth = Utils.auth(state, channel, user_data)
    frame = Frame.subscribe(channel, auth, user_data)

    @client.ws_send(conn_pid, {:text, Frame.encode!(frame)})
  end

  @spec init_state({map, module, list}) :: %State{}
  defp init_state({pusher_opts, callback_module, init_channels}) do
    %State{
      options: %Options{} |> Map.merge(pusher_opts),
      url: Utils.url(pusher_opts),
      callback_module: callback_module,
      init_channels: init_channels
    }
  end

  @spec do_init_channels(list) :: term
  defp do_init_channels([[name: channel, user_data: user_data] | other_channels]) do
    GenServer.cast(__MODULE__, {:subscribe, channel, user_data})
    do_init_channels(other_channels)
  end

  defp do_init_channels([]), do: nil
end
