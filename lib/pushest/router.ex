defmodule Pushest.Router do
  @moduledoc ~S"""
  Routes calls/cast from a module using Pushest to either Socket or Api GenServers.
  """

  alias Pushest.{Api, Socket}

  @type cast_term ::
          {:subscribe, String.t(), map}
          | {:trigger, String.t(), String.t(), map}
          | {:unsubscribe, String.t()}

  @type call_term :: :presence | :channels | :subscribed_channels

  @typedoc ~S"""
  Optional options for cast function.

  - `:force_api` - Always triggers via Pusher REST API endpoint when set to `true`
  """
  @type cast_opts :: [force_api: boolean]

  @doc ~S"""
  Async cast either `Socket` or `Api` GenServers with given message.
  """
  @spec cast(cast_term) :: :ok
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

  @spec cast({:trigger, String.t(), String.t(), map}, cast_opts) :: :ok
  def cast({:trigger, channel, event, data}, force_api: true) do
    GenServer.cast(Api, {:trigger, channel, event, data})
  end

  @doc ~S"""
  Sync call either `Socket` or `Api` GenServers with given message.
  """
  @spec call(call_term) :: term
  def call(:presence) do
    GenServer.call(Socket, :presence)
  end

  def call(:channels) do
    GenServer.call(Api, :channels)
  end

  def call(:subscribed_channels) do
    GenServer.call(Socket, :channels)
  end

  @spec client_mod(String.t()) :: module
  defp client_mod(channel) do
    subscribed = Enum.member?(call(:subscribed_channels), channel)
    if(subscribed, do: Socket, else: Api)
  end
end
