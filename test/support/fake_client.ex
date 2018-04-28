defmodule Pushest.FakeClient do
  @moduledoc false

  use GenServer

  def start_link do
    GenServer.start_link(
      __MODULE__,
      %{
        await_up: :ok,
        last_frame: nil,
        fail_unsubscribe: false,
        channels: %{},
        presence: %{count: 0, hash: %{}, ids: []}
      },
      name: __MODULE__
    )
  end

  def setup(payload) do
    GenServer.call(__MODULE__, {:setup, payload})
  end

  def last_frame do
    GenServer.call(__MODULE__, :last_frame)
  end

  def reset_presence do
    GenServer.call(__MODULE__, :reset_presence)
  end

  def open(_domain, _port) do
    {:ok, self()}
  end

  def establish_connection do
    GenServer.call(__MODULE__, :establish_connection)
  end

  ## WS Fake methods

  def await_up(_pid) do
    GenServer.call(__MODULE__, :await_up)
  end

  def ws_upgrade(_conn_pid, _path) do
    {:ok, nil}
  end

  def ws_send(_conn_pid, {:text, frame}) do
    GenServer.cast(__MODULE__, {:ws, %{payload: frame, via: :ws}})
  end

  ## API Fake methods

  def post(_pid, path, headers, frame) do
    GenServer.cast(
      __MODULE__,
      {:api, %{payload: frame, via: :api, path: path, headers: headers}}
    )
  end

  def get(_pid, path, headers) do
    GenServer.call(
      __MODULE__,
      {:api, %{via: :api, path: path, headers: headers}}
    )
  end

  def await(_conn_pid, _stream_ref) do
    {:response, :nofin, 200, []}
  end

  def await_body(_conn_pid, _stream_ref) do
    {:ok, Poison.encode!(GenServer.call(__MODULE__, :channels))}
  end

  ## Server callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_call({:setup, payload}, _from, state) do
    {:reply, {:ok, :setup}, Map.merge(state, payload)}
  end

  def handle_call(:reset_presence, _from, state) do
    {
      :reply,
      :ok,
      Map.merge(state, %{presence: %{count: 0, hash: %{}, ids: []}})
    }
  end

  def handle_call(:await_up, _from, state = %{await_up: status}) do
    case status do
      :ok -> {:reply, {:ok, :http}, state}
      :error -> {:reply, {:error, "invalid_message"}, state}
    end
  end

  def handle_call(:last_frame, _from, state = %{last_frame: last_frame}) do
    {:reply, {:ok, last_frame}, state}
  end

  def handle_call(:establish_connection, _from, state) do
    response =
      Poison.encode!(%{
        event: "pusher:connection_established",
        data: %{
          socket_id: "123.456",
          activity_timeout: 500
        }
      })

    send(Pushest.Adapters.Socket, {:gun_ws, self(), {:text, response}})

    {:reply, :ok, state}
  end

  def handle_call({:api, frame}, _from, state) do
    {:reply, :ok, Map.merge(state, %{last_frame: frame})}
  end

  def handle_call(:channels, _from, state = %{channels: channels}) do
    {:reply, %{channels: channels}, state}
  end

  def handle_cast({:api, frame}, state) do
    {:noreply, Map.merge(state, %{last_frame: frame})}
  end

  def handle_cast(
        {:ws, frame = %{payload: payload}},
        state = %{presence: presence, fail_unsubscribe: fail_unsubscribe}
      ) do
    decoded = Poison.decode!(payload)
    next_presence = decoded["data"]["channel_data"] |> decode_data() |> data(presence)
    channel = decoded["data"]["channel"]

    case decoded["event"] do
      "pusher:subscribe" ->
        response =
          Poison.encode!(%{
            event: "pusher_internal:subscription_succeeded",
            channel: channel,
            data: %{
              presence: next_presence
            }
          })

        send(Pushest.Adapters.Socket, {:gun_ws, self(), {:text, response}})

      "pusher:unsubscribe" when fail_unsubscribe ->
        response =
          Poison.encode!(%{
            event: "pusher:error",
            data: %{
              message:
                "No current subscription to channel #{channel}, or subscription in progress"
            }
          })

        send(Pushest.Adapters.Socket, {:gun_ws, self(), {:text, response}})

      _ ->
        nil
    end

    {:noreply, Map.merge(state, %{last_frame: frame, presence: next_presence})}
  end

  defp decode_data(nil), do: nil
  defp decode_data(channel_data), do: Poison.decode!(channel_data)

  defp data(channel_data, presence) when channel_data == nil, do: presence
  defp data(channel_data, presence) when channel_data == %{}, do: presence
  defp data(%{"user_id" => nil}, presence), do: presence

  defp data(%{"user_id" => user_id, "user_info" => user_info}, presence) do
    %{
      count: presence[:count] + 1,
      ids: [user_id | presence[:ids]],
      hash: Map.merge(presence[:hash], %{user_id => user_info})
    }
  end

  defp data(%{"user_id" => user_id}, presence) do
    %{
      count: presence[:count] + 1,
      ids: [user_id | presence[:ids]],
      hash: presence[:hash]
    }
  end
end
