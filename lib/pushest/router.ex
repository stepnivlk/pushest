defmodule Pushest.Router do
  @moduledoc false

  alias Pushest.{Api, Socket}

  def send({:subscribe, channel, user_data}, _mod) do
    GenServer.cast(Socket, {:subscribe, channel, user_data})
  end

  def send({:trigger, channel = "private-" <> _rest, event, data}, _mod) do
    GenServer.cast(Socket, {:trigger, channel, event, data})
  end

  def send({:trigger, channel = "presence-" <> _rest, event, data}, _mod) do
    GenServer.cast(Socket, {:trigger, channel, event, data})
  end

  def send({:trigger, channel, event, data}, _mod) do
    GenServer.cast(Api, {:trigger, channel, event, data})
  end
end
