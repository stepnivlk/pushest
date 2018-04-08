defmodule Pushest.Router do
  @moduledoc ~S"""
  Routes calls/cast from a module using Pushest to either Socket or Api GenServers.
  """

  alias Pushest.{Api, Socket}

  def cast({:subscribe, channel, user_data}) do
    GenServer.cast(Socket, {:subscribe, channel, user_data})
  end

  def cast({:trigger, channel = "private-" <> _rest, event, data}) do
    GenServer.cast(client_mod(channel), {:trigger, channel, event, data})
  end

  def cast({:trigger, channel = "presence-" <> _rest, event, data}) do
    GenServer.cast(client_mod(channel), {:trigger, channel, event, data})
  end

  def cast({:trigger, channel, event, data}) do
    GenServer.cast(Api, {:trigger, channel, event, data})
  end

  def cast({:unsubscribe, channel}) do
    GenServer.cast(Socket, {:unsubscribe, channel})
  end

  def cast({:trigger, channel, event, data}, force_api: true) do
    GenServer.cast(Api, {:trigger, channel, event, data})
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

  defp client_mod(channel) do
    subscribed = Enum.member?(call(:subscribed_channels), channel)
    if(subscribed, do: Socket, else: Api)
  end
end
