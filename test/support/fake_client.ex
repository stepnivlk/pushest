defmodule Pushest.FakeClient do
  @moduledoc false

  use GenServer

  def start_link() do
    GenServer.start_link(
      __MODULE__,
      %{await_up: :ok, last_frame: nil, presence: %{count: 0, hash: %{}, ids: []}},
      name: __MODULE__
    )
  end

  def setup(payload) do
    GenServer.call(__MODULE__, {:setup, payload})
  end

  def last_frame do
    GenServer.call(__MODULE__, :last_frame)
  end

  def open(_domain, _port) do
    {:ok, self()}
  end

  ## Fake methods

  def await_up(_pid) do
    GenServer.call(__MODULE__, :await_up)
  end

  def ws_upgrade(_conn_pid, _path) do
    {:ok, nil}
  end

  def ws_send(_conn_pid, {:text, frame}) do
    GenServer.cast(__MODULE__, {:frame, frame})
  end

  ## Server callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_call({:setup, payload}, _from, state) do
    {:reply, {:ok, :setup}, Map.merge(state, payload)}
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

  def handle_cast({:frame, frame}, state = %{parent_pid: parent_pid, presence: presence}) do
    decoded = Poison.decode!(frame)
    next_presence = decoded["data"]["channel_data"] |> decode_data() |> data(presence)

    case decoded["event"] do
      "pusher:subscribe" ->
        response =
          Poison.encode!(%{
            event: "pusher_internal:subscription_succeeded",
            channel: decoded["data"]["channel"],
            data: %{
              presence: next_presence
            }
          })

        send(parent_pid, {:gun_ws, self(), {:text, response}})
      _ -> nil
    end

    {:noreply, Map.merge(state, %{last_frame: frame, presence: next_presence})}
  end

  defp decode_data(nil), do: nil
  defp decode_data(channel_data), do: Poison.decode!(channel_data)

  defp data(channel_data, _presence) when channel_data == nil, do: %{}
  defp data(channel_data, _presence) when channel_data == %{}, do: %{}
  defp data(%{"user_id" => nil}, _presence), do: %{}
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
