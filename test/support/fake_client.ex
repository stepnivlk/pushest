defmodule Pushest.FakeClient do
  @moduledoc false

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{await_up: :ok, last_frame: nil}, name: __MODULE__)
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

  def handle_cast({:frame, frame}, state) do
    {:noreply, Map.put(state, :last_frame, frame)}
  end
end
