defmodule Pushest.Socket do
  @moduledoc false

  require Logger

  use GenServer

  alias __MODULE__.Utils
  alias __MODULE__.Data.{State, Frame, Url, Presence, SocketInfo}
  alias Pushest.Data.Options

  @client Application.get_env(:pushest, :conn_client)

  def start_link(pusher_opts) do
    GenServer.start_link(__MODULE__, init_state(pusher_opts), [])
  end

  def init(state = %State{url: %Url{domain: domain, path: path, port: port}}) do
    {:ok, conn_pid} = @client.open(domain, port)
    m_ref = Process.monitor(conn_pid)

    case @client.await_up(conn_pid) do
      {:ok, :http} ->
        @client.ws_upgrade(conn_pid, path)
        {:ok, %{state | conn_pid: conn_pid, m_ref: m_ref}}

      {:error, msg} ->
        {:stop, "Connection init error #{inspect(msg)}"}
    end
  end

  def trigger(channel, event, data) do
    GenServer.cast(__MODULE__, {:trigger, channel, event, data})
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
          "#{channel} is a presence channel and subscription must include channel_data"
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
        state = %State{channels: channels, presence: presence}
      ) do
    frame = Frame.decode!(raw_frame)

    case frame.event do
      "pusher:connection_established" ->
        Logger.debug("pusher:connection_established")
        {:noreply, %{state | socket_info: SocketInfo.decode(frame.data)}}

      "pusher_internal:subscription_succeeded" ->
        presence = Presence.merge(presence, frame.data["presence"])
        {:noreply, %{state | channels: [frame.channel | channels], presence: presence}}

      "pusher_internal:member_added" ->
        Logger.debug("pusher_internal:member_added")
        {:noreply, %{state | presence: Presence.add_member(presence, frame.data)}}

      "pusher_internal:member_removed" ->
        Logger.debug("pusher_internal:member_removed")
        {:noreply, %{state | presence: Presence.remove_member(presence, frame.data)}}

      "pusher:error" ->
        message = Map.get(frame.data, "message")
        Logger.debug(fn -> "pusher:error #{inspect(message)}" end)
        # try_callback(module, :handle_event, [{:error, message}, frame])
        {:noreply, state}

      _ ->
        # try_callback(module, :handle_event, [{:ok, frame.channel, frame.event}, frame])
        {:noreply, state}
    end
  end

  def handle_info(params, state) do
    Logger.debug(fn -> "pusher:event #{inspect(params)}" end)
    {:noreply, state}
  end

  @spec do_subscribe(String.t(), map, %State{}) :: term
  defp do_subscribe(channel, user_data, state = %State{conn_pid: conn_pid}) do
    auth = Utils.auth(state, channel, user_data)
    frame = Frame.subscribe(channel, auth, user_data)

    @client.ws_send(conn_pid, {:text, Frame.encode!(frame)})
  end

  @spec init_state(map) :: %State{}
  defp init_state(pusher_opts) do
    %State{
      options: %Options{} |> Map.merge(pusher_opts),
      url: Utils.url(pusher_opts)
    }
  end
end
