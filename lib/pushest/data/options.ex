defmodule Pushest.Data.Options do
  @moduledoc ~S"""
  Structure representing main Pusher options which are passed via Pushest
  initializating methods.
  """

  @type t :: %__MODULE__{
          app_id: String.t(),
          key: String.t(),
          cluster: String.t(),
          secret: String.t(),
          encrypted: boolean
        }

  defstruct [:app_id, :key, :cluster, :encrypted, :secret]
end
