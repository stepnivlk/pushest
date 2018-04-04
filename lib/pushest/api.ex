defmodule Pushest.Api do
  @moduledoc false

  use GenServer

  require Logger

  alias __MODULE__.Utils
  alias __MODULE__.Data.{Frame, Url}

  @client Pushest.Client.for_env()
  @version Mix.Project.config()[:version]

  def start_link({pusher_opts, callback_module}) do
    GenServer.start_link(
      __MODULE__,
      %{url: Utils.url(pusher_opts), options: pusher_opts},
      name: __MODULE__
    )
  end

  def init(state = %{url: %Url{domain: domain, port: port}}) do
    {:ok, conn_pid} = @client.open(domain, port)
    m_ref = Process.monitor(conn_pid)
    {:ok, _protocol} = @client.await_up(conn_pid)

    {:ok, Map.merge(state, %{conn_pid: conn_pid, m_ref: m_ref})}
  end

  def handle_call(:channels, _from, state = %{conn_pid: conn_pid, options: options}) do
    path = "GET" |> Utils.full_path("channels", options) |> to_charlist
    stream_ref = @client.get(conn_pid, path, headers())

    {:reply, client_sync(conn_pid, stream_ref), state}
  end

  def handle_cast(
        {:trigger, channel, event, data},
        state = %{conn_pid: conn_pid, options: options}
      ) do
    frame =
      channel
      |> Frame.event(event, data)
      |> Frame.encode!()

    path = "POST" |> Utils.full_path("events", options, frame) |> to_charlist

    @client.post(conn_pid, path, headers(), frame)

    {:noreply, state}
  end

  def handle_info({:gun_response, _conn_pid, _stream_ref, :fin, _status, _headers}, state) do
    # no data
    {:noreply, state}
  end

  def handle_info(
        {:gun_response, conn_pid, stream_ref, :nofin, status, headers},
        state = %{conn_pid: conn_pid}
      ) do
    {:ok, _body} = :gun.await_body(conn_pid, stream_ref)

    {:noreply, state}
  end

  def handle_info({:gun_down, _conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams}, state) do
    Logger.error(":gun_down #{reason}")
    {:noreply, state}
  end

  def handle_info({:gun_up, _conn_pid, _protocol}, state) do
    Logger.debug(":gun_up")
    {:noreply, state}
  end

  defp headers do
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
    end
  end
end
