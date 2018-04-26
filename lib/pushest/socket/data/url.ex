defmodule Pushest.Socket.Data.Url do
  @moduledoc ~S"""
  Structure used to construct URL for Pusher server.
  """

  @type t :: %__MODULE__{
    domain: String.t(),
    path: String.t(),
    port: integer
  }

  defstruct [:domain, :path, :port]
end
