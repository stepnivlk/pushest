defmodule Pushest.Data.Options do
  @moduledoc ~S"""
  Structure representing main Pusher options which are passed via Pushest
  initializating methods.
  """

  defstruct [:app_id, :key, :cluster, :encrypted, :secret]
end
