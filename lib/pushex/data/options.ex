defmodule Pushex.Data.Options do
  @moduledoc ~S"""
  Structure representing main Pusher options which are passed via Pushex
  initializating methods.
  """

  defstruct [:cluster, :encrypted, :secret]
end
