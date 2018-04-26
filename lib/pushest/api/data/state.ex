defmodule Pushest.Api.Data.State do
  @moduledoc ~S"""
  Structure representing whole App state being held in GenServer process.
  """

  alias Pushest.Api.Data.Url
  alias Pushest.Data.Options

  @type t :: %__MODULE__{
          url: %Url{},
          options: %Options{},
          conn_pid: nil | pid
        }

  defstruct url: %Url{}, options: %Options{}, conn_pid: nil
end
