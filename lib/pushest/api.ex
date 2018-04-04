defmodule Pushest.Api do
  @moduledoc false

  use GenServer

  require Logger

  alias __MODULE__.Utils
  alias __MODULE__.Data.{Frame, Url}

  @client Pushest.Client.for_env()
  @version Mix.Project.config()[:version]

  def start_link(pusher_opts) do
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

  def handle_cast(
        {:trigger, channel, event, data},
        state = %{conn_pid: conn_pid, options: options}
      ) do
    frame =
      channel
      |> Frame.event(event, data)
      |> Frame.encode!()

    path = "POST" |> Utils.full_path("events", frame, options) |> to_charlist

    @client.post(
      conn_pid,
      path,
      [
        {"content-type", "application/json"},
        {"X-Pusher-Library", "Pushest #{@version}"}
      ],
      frame
    )

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
    {:ok, body} = :gun.await_body(conn_pid, stream_ref)
    IO.inspect({headers, status, body})
    {:noreply, state}
  end

  def handle_info({:gun_down, _conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams}, state) do
    Logger.error(":gun_down #{reason}")
    {:noreply, state}
  end
end
