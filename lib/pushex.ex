defmodule Pushex do
  @moduledoc false

  use GenServer

  require Logger

  alias Pushex.Data.{State, Frame, SocketInfo, Options, Url}
  alias Pushex.Helpers

  @callback handle_event({atom, String.t(), String.t()}, term) :: term

  defmacro __using__(_opts) do
    quote do
      require Logger
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

      def unsubscribe(pid, channel) do
        GenServer.cast(pid, {:unsubscribe, channel})
      end

      def unsubscribe(channel) do
        GenServer.cast(__MODULE__, {:unsubscribe, channel})
      end

      def handle_event({:ok, channel, event}, frame) do
        Logger.error(
          "No :ok handle_event/2 clause in #{__MODULE__} provided for #{inspect(frame)}"
        )
      end

      def handle_event({:error, message}, frame) do
        Logger.error(
          "No :error handle_event/2 clause in #{__MODULE__} provided for #{inspect(frame)}"
        )
      end

      defoverridable handle_event: 2
    end
  end

  def start_link(app_key, pusher_opts, module, opts \\ []) do
    state = init_state(app_key, pusher_opts, module)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state = %State{url: %Url{domain: domain, path: path, port: port}}) do
    {:ok, conn_pid} = :gun.open(domain, port)

    case :gun.await_up(conn_pid) do
      {:ok, :http} -> :gun.ws_upgrade(conn_pid, path)
      {:error, msg} -> raise "Connection init error #{inspect(msg)}"
    end

    {:ok, %{state | conn_pid: conn_pid}}
  end

  def handle_cast({:subscribe, channel = "presence-" <> _rest, user_data}, state) do
    case Helpers.validate_user_data(user_data) do
      {:ok, user_data} ->
        do_subscribe(channel, user_data, state)

      {:error, _} ->
        Logger.error(
          "#{channel} is a presence channel and subscription must include channel_data"
        )
    end

    {:noreply, state}
  end

  def handle_cast({:subscribe, channel, user_data}, state) do
    do_subscribe(channel, user_data, state)
    {:noreply, state}
  end

  def handle_cast({:unsubscribe, channel}, state = %State{conn_pid: conn_pid, channels: channels}) do
    frame = Frame.unsubscribe(channel)

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

  def handle_call(:channels, _from, state = %State{channels: channels}) do
    {:reply, channels, state}
  end

  def handle_info({:gun_ws_upgrade, _conn_pid, :ok, _headers}, state) do
    IO.puts(:gun_ws_upgrade)
    {:noreply, state}
  end

  def handle_info(
        {:gun_ws, _conn_pid, {:text, raw_frame}},
        state = %State{module: module, channels: channels}
      ) do
    frame = raw_frame |> Frame.decode!()

    case frame.event do
      "pusher:connection_established" ->
        Logger.debug("pusher:connection_established")
        {:noreply, %{state | socket_info: SocketInfo.decode!(frame.data)}}

      "pusher_internal:subscription_succeeded" ->
        Logger.debug("pusher_internal:subscription_succeeded")
        {:noreply, %{state | channels: [frame.channel | channels]}}

      "pusher:error" ->
        Logger.debug("pusher:error")
        message = Map.get(frame.data, "message")
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
      url: Helpers.url(app_key, options),
      options: %Options{} |> Map.merge(options),
      module: module
    }
  end

  defp do_subscribe(channel, user_data, state = %State{conn_pid: conn_pid}) do
    frame =
      channel
      |> Frame.subscribe(Helpers.auth(state, channel), user_data)
      |> Frame.encode!()

    :gun.ws_send(conn_pid, {:text, frame})
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
