defmodule Pushest.Api do
  @moduledoc false

  use GenServer

  require Logger

  alias __MODULE__.Utils
  alias __MODULE__.Data.{State, Frame, Url}
  alias Pushest.Data.Options

  @client Pushest.Client.for_env()
  @version Mix.Project.config()[:version]

  def start_link({pusher_opts, _callback_module}) do
    GenServer.start_link(
      __MODULE__,
      %State{url: Utils.url(pusher_opts), options: %Options{} |> Map.merge(pusher_opts)},
      name: __MODULE__
    )
  end

  def init(state = %State{url: %Url{domain: domain, port: port}}) do
    {:ok, conn_pid} = @client.open(domain, port)
    Process.monitor(conn_pid)

    case @client.await_up(conn_pid) do
      {:ok, _protocol} ->
        {:ok, %{state | conn_pid: conn_pid}}

      {:error, msg} ->
        {:stop, "Connection init error #{inspect(msg)}"}
    end
  end

  def handle_call(:channels, _from, state = %State{conn_pid: conn_pid, options: options}) do
    path = "GET" |> Utils.full_path("channels", options) |> to_charlist
    stream_ref = @client.get(conn_pid, path, get_headers())

    {:reply, client_sync(conn_pid, stream_ref), state}
  end

  def handle_cast(
        {:trigger, channel, event, data},
        state = %State{conn_pid: conn_pid, options: options}
      ) do
    frame =
      channel
      |> Frame.event(event, data)
      |> Frame.encode!()

    path = "POST" |> Utils.full_path("events", options, frame) |> to_charlist

    @client.post(conn_pid, path, post_headers(), frame)

    {:noreply, state}
  end

  def handle_info({:gun_response, _conn_pid, _stream_ref, :fin, _status, _headers}, state) do
    # no data
    {:noreply, state}
  end

  def handle_info(
        {:gun_response, conn_pid, stream_ref, :nofin, status, _headers},
        state = %State{conn_pid: conn_pid}
      ) do
    case status do
      200 -> {:ok, _body} = :gun.await_body(conn_pid, stream_ref)
      _ -> Logger.error("Pusher API status #{status}")
    end

    {:noreply, state}
  end

  def handle_info({:gun_down, _conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams}, state) do
    Logger.error(":gun_down #{reason}")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _object, reason}, state) do
    Logger.error(":DOWN #{reason}")
    {:noreply, state}
  end

  def handle_info({:gun_up, _conn_pid, protocol}, state) do
    Logger.debug(fn -> ":gun_up #{protocol}" end)
    {:noreply, state}
  end

  defp get_headers do
    [
      {"X-Pusher-Library", "Pushest #{@version}"}
    ]
  end

  defp post_headers do
    [
      {"content-type", "application/json"},
      {"X-Pusher-Library", "Pushest #{@version}"}
    ]
  end

  defp client_sync(conn_pid, stream_ref) do
    case @client.await(conn_pid, stream_ref) do
      {:response, :fin, _status, _headers} ->
        :no_data
      {:response, :nofin, _status, _headers} ->
        {:ok, body} = @client.await_body(conn_pid, stream_ref)
        Poison.decode!(body)
      {:error, reason} ->
        Logger.error(":gun_fail #{inspect reason}")
    end
  end
end
