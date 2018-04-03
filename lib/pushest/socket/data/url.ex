defmodule Pushest.Socket.Data.Url do
  @moduledoc ~S"""
  Structure used to construct URL for Pusher server.
  """

  defstruct [:domain, :path, :port]
end
