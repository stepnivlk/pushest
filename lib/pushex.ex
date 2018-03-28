defmodule Pushex do
  @moduledoc ~S"""
  Pushex handles communication with Pusher server via wesockets. Abstracts
  un/subscription, client-side triggers, private/presence channel authorizations.
  Keeps track of subscribed channels and users presence when subscribed to presence channel.
  Pushex is meant to be used in your module where you can define callbacks for
  events you're interested in.

  A simple implementation would be:
  defmodule SimpleClient do
    use Pushex

    def start_link() do
      options = %{
        cluster: "eu",
        encrypted: true,
        secret: "SECRET"
      }
      Pushex.start_link("APP_KEY", options, __MODULE__, name: __MODULE__)
    end

    def handle_event({:ok, "public-channel", "some-event"}, frame) do
      # do something with public frame
    end

    def handle_event({:ok, "private-channel", "some-other-event"}, frame) do
      # do something with private frame
    end
  end
  """

  @typedoc ~S"""
  Options for Pushex to properly communicate with Pusher server.

  - `:cluster` - Cluster where your Pusher app is configured.
  - `:encrypted` - When set to true communication with Pusher is fully encrypted.
  - `:secret` - Necessary to subscribe to private/presence channels and trigger events.
  """
  @type pusher_opts :: %{cluster: String.t(), encrypted: boolean, secret: String.t()}

  use GenServer

  require Logger

  alias Pushex.Data.{State, Frame, SocketInfo, Options, Url, Presence}
  alias Pushex.Utils

  @doc ~S"""
  Invoked when the Pusher event occurs (e.g. other client sends a message).
  """
  @callback handle_event({atom, String.t(), String.t()}, term) :: term

  defmacro __using__(_opts) do
    quote do
      @behaviour Pushex

      def subscribe(pid, channel, user_data) do
        GenServer.cast(pid, {:subscribe, channel, user_data})
      end

      def subscribe(pid, channel) when is_pid(pid) do
        GenServer.cast(pid, {:subscribe, channel, %{}})
      end

      def subscribe(channel, user_data) do
        GenServer.cast(__MODULE__, {:subscribe, channel, user_data})
      end

      def subscribe(channel) do
        GenServer.cast(__MODULE__, {:subscribe, channel, %{}})
      end

      def trigger(pid, channel, event, data) do
        GenServer.cast(pid, {:trigger, channel, event, data})
      end

      def trigger(channel, event, data) do
        GenServer.cast(__MODULE__, {:trigger, channel, event, data})
      end

      def channels(pid) do
        GenServer.call(pid, :channels)
      end

      def channels do
        GenServer.call(__MODULE__, :channels)
      end

      def presence(pid) do
        GenServer.call(pid, :presence)
      end

      def presence do
        GenServer.call(__MODULE__, :presence)
      end

      def unsubscribe(pid, channel) do
        GenServer.cast(pid, {:unsubscribe, channel})
      end

      def unsubscribe(channel) do
        GenServer.cast(__MODULE__, {:unsubscribe, channel})
      end

      def handle_event({status, channel, event}, frame) do
        require Logger

        Logger.error(
          "No #{inspect(status)} handle_event/2 clause in #{__MODULE__} provided for #{
            inspect(event)
          }"
        )
      end

      defoverridable handle_event: 2
    end
  end

  @doc ~S"""
  Starts a Pushex process linked to current process.
  Please note, you need to provide a module as a third element, Pushex will try
  to invoke `handle_event` callbacks in that module when Pusher event occurs.

  For available pusher_opts values see `t:pusher_opts/0`.
  """
  @spec start_link(String.t(), pusher_opts, module, list) :: {:ok, pid} | {:error, term}
  def start_link(app_key, pusher_opts, module, opts \\ []) do
    state = init_state(app_key, pusher_opts, module)

    GenServer.start_link(__MODULE__, state, opts)
  end

  @spec init(%State{}) :: {:ok, %State{}}
  def init(state = %State{url: %Url{domain: domain, path: path, port: port}}) do
    {:ok, conn_pid} = :gun.open(domain, port)

    case :gun.await_up(conn_pid) do
      {:ok, :http} -> :gun.ws_upgrade(conn_pid, path)
      {:error, msg} -> raise "Connection init error #{inspect(msg)}"
    end

    {:ok, %{state | conn_pid: conn_pid}}
  end

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

    :gun.ws_send(conn_pid, {:text, frame})

    {:noreply, %{state | channels: List.delete(channels, channel)}}
  end

  def handle_cast({:trigger, channel, event, data}, state = %State{conn_pid: conn_pid}) do
    frame =
      channel
      |> Frame.event(event, data)
      |> Frame.encode!()

    :gun.ws_send(conn_pid, {:text, frame})

    {:noreply, state}
  end

  @spec handle_call(:channels | :presence, {pid, term}, %State{}) ::
          {:reply, list | %Presence{}, %State{}}
  def handle_call(:channels, _from, state = %State{channels: channels}) do
    {:reply, channels, state}
  end

  def handle_call(:presence, _from, state = %State{presence: presence}) do
    {:reply, presence, state}
  end

  def handle_info({:gun_ws_upgrade, _conn_pid, :ok, _headers}, state) do
    {:noreply, state}
  end

  def handle_info(
        {:gun_ws, _conn_pid, {:text, raw_frame}},
        state = %State{module: module, channels: channels, presence: presence}
      ) do
    frame = Frame.decode!(raw_frame)

    case frame.event do
      "pusher:connection_established" ->
        Logger.debug("pusher:connection_established")
        {:noreply, %{state | socket_info: SocketInfo.decode(frame.data)}}

      "pusher_internal:subscription_succeeded" ->
        Logger.debug("pusher_internal:subscription_succeeded")
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
        try_callback(module, :handle_event, [{:error, message}, frame])
        {:noreply, state}

      _ ->
        try_callback(module, :handle_event, [{:ok, frame.channel, frame.event}, frame])
        {:noreply, state}
    end
  end

  def handle_info(params, state) do
    Logger.debug(fn -> "pusher:event #{inspect(params)}" end)
    {:noreply, state}
  end

  defp init_state(app_key, options, module) do
    %State{
      app_key: app_key,
      url: Utils.url(app_key, options),
      options: %Options{} |> Map.merge(options),
      module: module
    }
  end

  defp do_subscribe(channel, user_data, state = %State{conn_pid: conn_pid}) do
    auth = Utils.auth(state, channel, user_data)
    frame = Frame.subscribe(channel, auth, user_data)

    :gun.ws_send(conn_pid, {:text, Frame.encode!(frame)})
  end

  defp try_callback(module, function, args) do
    apply(module, function, args)
  catch
    :error, payload ->
      stacktrace = System.stacktrace()
      reason = Exception.normalize(:error, payload, stacktrace)
      {:"$EXIT", {reason, stacktrace}}

    :exit, payload ->
      {:"$EXIT", payload}
  end
end
