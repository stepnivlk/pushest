defmodule Pushest.Api.Data.Url do
  @moduledoc ~S"""
  Structure used to construct URL for Pusher server.
  """

  @type t :: %__MODULE__{
          domain: String.t(),
          port: integer
        }

  defstruct [:domain, :port]
end
