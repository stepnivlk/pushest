defmodule Pushest.Api do
  @moduledoc ~S"""
  GenServer responsible for communication with Pusher via REST API endpoint.
  This module is meant to be used internally as part of the Pushest application.
  """

  use GenServer

  require Logger

  alias __MODULE__.Utils
  alias __MODULE__.Data.{State, Frame, Url}
  alias Pushest.Data.Options

  @client Pushest.Client.for_env()
  @version Mix.Project.config()[:version]

  def start_link({pusher_opts, _callback_module, _init_channels}) do
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
        {:stop, "Api | Connection init error #{inspect(msg)}"}
    end
  end

  @doc ~S"""
  Sync server-side callback handling all the channels listing.
  """
  @spec handle_call(atom, {pid, term}, %State{}) :: {:reply, term, %State{}}
  def handle_call(:channels, _from, state = %State{conn_pid: conn_pid, options: options}) do
    path = "GET" |> Utils.full_path("channels", options) |> to_charlist
    stream_ref = @client.get(conn_pid, path, get_headers())

    {:reply, client_sync(conn_pid, stream_ref), state}
  end

  @doc ~S"""
  Async server-side callback handling trigger for given channel/event combination
  with given data payload.
  """
  @spec handle_cast({atom, String.t(), String.t(), map}, %State{}) :: {:noreply, %State{}}
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

  @doc ~S"""
  Handle various gun responses based on the shape of incoming message.
  """
  @spec handle_info(term, %State{}) :: {:noreply, %State{}}
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
      _ -> Logger.error("Api | Pusher response status #{inspect(status)}")
    end

    {:noreply, state}
  end

  def handle_info(
        {:gun_down, _conn_pid, _protocol, reason, _killed_streams, _unprocessed_streams},
        state
      ) do
    Logger.error(":gun_down #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _object, reason}, state) do
    Logger.error("Api | :DOWN #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info({:gun_up, _conn_pid, protocol}, state) do
    Logger.debug(fn -> "Api | :gun_up #{inspect(protocol)}" end)
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
        Logger.error(":gun_fail #{inspect(reason)}")
    end
  end
end
