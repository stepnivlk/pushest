defmodule Pushest.Socket.Data.SubscriptionData do
  @moduledoc ~S"""
  Structure representing a specific data payload being sent as part of a
  subscription event.
  """

  defstruct [:channel, :auth, :channel_data]
end
