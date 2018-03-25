defmodule Pushex.Socket do
  @moduledoc false

  use GenServer

  alias Pushex.Structs.{State, Frame, SocketInfo, Options, Url}
  alias Pushex.Helpers

  def start_link(app_key, pusher_opts, opts \\ []) do
    state = init_state(app_key, pusher_opts)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def subscribe(pid, channel) do
    GenServer.cast(pid, {:subscribe, channel})
  end

  def trigger(pid, channel, event, data) do
    GenServer.cast(pid, {:trigger, channel, event, data})
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
    IO.puts :gun_ws_upgrade
    {:noreply, state}
  end

  def handle_info({:gun_ws, _conn_pid, {:text, raw_frame}}, state) do
    frame = raw_frame |> Frame.decode!()

    IO.inspect frame

    case frame.event do
      "pusher:connection_established" ->
        {:noreply, %{state | socket_info: SocketInfo.decode!(frame.data)}}

      "pusher_internal:subscription_succeeded" ->
        {:noreply, %{state | channels: [frame.channel | state.channels]}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(params, state) do
    IO.inspect params
    {:noreply, state}
  end

  defp init_state(app_key, options) do
    %State{
      app_key: app_key,
      url: Helpers.url(app_key, options),
      options: %Options{} |> Map.merge(options)
    }
  end
end
