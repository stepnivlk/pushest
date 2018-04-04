defmodule Pushest.Router do
  @moduledoc false

  alias Pushest.{Api, Socket}

  def cast({:subscribe, channel, user_data}) do
    GenServer.cast(Socket, {:subscribe, channel, user_data})
  end

  def cast({:trigger, channel, event, data}) do
    subscribed = Enum.member?(call(:subscribed_channels), channel)
    client_mod = if(subscribed, do: Socket, else: Api)

    GenServer.cast(client_mod, {:trigger, channel, event, data})
  end

  def cast({:unsubscribe, channel}) do
    GenServer.cast(Socket, {:unsubscribe, channel})
  end

  def call(:presence) do
    GenServer.call(Socket, :presence)
  end

  def call(:channels) do
    GenServer.call(Api, :channels)
  end

  def call(:subscribed_channels) do
    GenServer.call(Socket, :channels)
  end
end
