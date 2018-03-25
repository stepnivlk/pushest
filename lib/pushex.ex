defmodule Pushex do
  @moduledoc false

  use GenServer

  require Logger

  alias Pushex.Data.{State, Frame, SocketInfo, Options, Url}
  alias Pushex.Helpers

  @callback handle_event({String.t(), term}) :: {:ok, term}

  defmacro __using__(_opts) do
    quote do
      require Logger
      @behaviour Pushex

      def subscribe(pid, channel) do
        GenServer.cast(pid, {:subscribe, channel})
      end

      def trigger(pid, channel, event, data) do
        GenServer.cast(pid, {:trigger, channel, event, data})
      end

      def handle_event({event, frame}) do
        Logger.error("No handle_event/1 clause in #{__MODULE__} provided for #{inspect(event)}")
        {:noreply, frame}
      end

      defoverridable handle_event: 1
    end
  end

  def start_link(app_key, pusher_opts, module, opts \\ []) do
    state = init_state(app_key, pusher_opts, module)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state = %State{url: %Url{domain: domain, path: path, port: port}}) do
    {:ok, conn_pid} = :gun.open(domain, port)
    {:ok, :http} = :gun.await_up(conn_pid)
    :gun.ws_upgrade(conn_pid, path)

    {:ok, %{state | conn_pid: conn_pid}}
  end

  def handle_cast({:subscribe, channel}, state = %State{conn_pid: conn_pid}) do
    frame =
      channel
      |> Frame.subscription(Helpers.auth(state, channel))
      |> Frame.encode!()

    :gun.ws_send(conn_pid, {:text, frame})

    {:noreply, state}
  end

  def handle_cast({:trigger, channel, event, data}, state = %State{conn_pid: conn_pid}) do
    frame =
      channel
      |> Frame.event(event, data)
      |> Frame.encode!()

    :gun.ws_send(conn_pid, {:text, frame})

    {:noreply, state}
  end

  def handle_info({:gun_ws_upgrade, _conn_pid, :ok, _headers}, state) do
    IO.puts(:gun_ws_upgrade)
    {:noreply, state}
  end

  def handle_info({:gun_ws, _conn_pid, {:text, raw_frame}}, state = %State{module: module}) do
    frame = raw_frame |> Frame.decode!()

    case frame.event do
      "pusher:connection_established" ->
        Logger.debug("pusher:connection_established")
        {:noreply, %{state | socket_info: SocketInfo.decode!(frame.data)}}

      "pusher_internal:subscription_succeeded" ->
        Logger.debug("pusher_internal:subscription_succeeded")
        {:noreply, state}

      _ ->
        try_callback(module, :handle_event, [{frame.event, frame}])
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
