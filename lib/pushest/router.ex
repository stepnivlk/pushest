defmodule Pushest.Router do
  @moduledoc ~S"""
  Routes calls/cast from a module using Pushest to either Socket or Api GenServers.
  """

  alias Pushest.Data.Options

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
  @spec cast(cast_term, %Options{}) :: :ok
  def cast({:subscribe, channel, user_data}, %Options{socket_adapter: socket_adapter}) do
    apply(socket_adapter, :cast, [{:subscribe, channel, user_data}])
  end

  def cast({:trigger, channel = "private-" <> _rest, event, data}, options = %Options{}) do
    apply(adapter_mod(channel, options), :cast, [{:trigger, channel, event, data}])
  end

  def cast({:trigger, channel = "presence-" <> _rest, event, data}, options = %Options{}) do
    apply(adapter_mod(channel, options), :cast, [{:trigger, channel, event, data}])
  end

  def cast({:trigger, channel, event, data}, %Options{api_adapter: api_adapter}) do
    apply(api_adapter, :cast, [{:trigger, channel, event, data}])
  end

  def cast({:unsubscribe, channel}, %Options{socket_adapter: socket_adapter}) do
    apply(socket_adapter, :cast, [{:unsubscribe, channel}])
  end

  @spec cast({:trigger, String.t(), String.t(), map}, %Options{}, cast_opts) :: :ok
  def cast({:trigger, channel, event, data}, %Options{api_adapter: api_adapter}, force_api: true) do
    apply(api_adapter, :cast, [{:trigger, channel, event, data}])
  end

  @doc ~S"""
  Sync call either `Socket` or `Api` GenServers with given message.
  """
  @spec call(call_term, %Options{}) :: term
  def call(:presence, %Options{socket_adapter: socket_adapter}) do
    apply(socket_adapter, :call, [:presence])
  end

  def call(:channels, %Options{api_adapter: api_adapter}) do
    apply(api_adapter, :call, [:channels])
  end

  def call(:subscribed_channels, %Options{socket_adapter: socket_adapter}) do
    apply(socket_adapter, :call, [:channels])
  end

  ## ==========================================================================
  ## Private
  ## ==========================================================================

  @spec adapter_mod(String.t(), %Options{}) :: module
  defp adapter_mod(
         channel,
         options = %Options{socket_adapter: socket_adapter, api_adapter: api_adapter}
       ) do
    subscribed = Enum.member?(call(:subscribed_channels, options), channel)
    if(subscribed, do: socket_adapter, else: api_adapter)
  end
end
