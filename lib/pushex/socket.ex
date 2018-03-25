defmodule Pushex.Socket do
  @moduledoc false
  use WebSockex

  alias Pushex.Structs.{State, Frame, SocketInfo, Options}

  alias Pushex.Helpers

  def start_link(app_key, options) do
    state = init_state(app_key, options)

    url = Helpers.url(app_key, state.options)

    WebSockex.start_link(url, __MODULE__, state)
  end

  def subscribe(pid, channel) do
    WebSockex.cast(pid, {:subscribe, channel})
  end

  def trigger(pid, channel, event, data) do
    WebSockex.cast(pid, {:trigger, channel, event, data})
  end

  def handle_frame({:text, raw_frame}, state) do
    frame = raw_frame |> Frame.decode!

    IO.inspect frame

    case frame.event do
      "pusher:connection_established" ->
        {:ok, %{state | socket_info: SocketInfo.decode!(frame.data)}}
      "pusher_internal:subscription_succeeded" ->
        {:ok, %{state | channels: [frame.channel | state.channels]}}
      _ -> {:ok, state}
    end
  end

  def handle_cast({:subscribe, channel}, state) do
    frame = Frame.subscription(channel, Helpers.auth(state, channel))

    {:reply, {:text, Frame.encode!(frame)}, state}
  end

  def handle_cas({:trigger, channel, event, data}, state) do
    frame = channel |> Frame.event(event, data) |> Frame.encode!

    {:reply, {:text, Frame.encode!(frame)}, state}
  end

  defp init_state(app_key, options) do
    %State{app_key: app_key, options: %Options{} |> Map.merge(options)}
  end
end
