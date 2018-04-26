defmodule Pushest.Socket.Data.SubscriptionData do
  @moduledoc ~S"""
  Structure representing a specific data payload being sent as part of a
  subscription event.
  """

  @type t :: %__MODULE__{
    channel: String.t(),
    auth: String.t(),
    channel_data: map
  }

  defstruct [:channel, :auth, :channel_data]
end
