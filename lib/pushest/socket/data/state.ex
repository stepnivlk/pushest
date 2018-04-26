defmodule Pushest.Socket.Data.State do
  @moduledoc ~S"""
  Structure representing whole App state being held in GenServer process.
  """

  alias Pushest.Socket.Data.{SocketInfo, Url, Presence}
  alias Pushest.Data.Options

  @type init_channel :: [name: String.t(), user_data: map]

  @type t :: %__MODULE__{
    url: %Url{},
    options: %Options{},
    socket_info: %SocketInfo{},
    channels: list(string),
    presence: %Presence{},
    conn_pid: pid | nil,
    callback_module: module | nil,
    init_channels: list(init_channel)
  }

  defstruct url: %Url{},
            options: %Options{},
            socket_info: %SocketInfo{},
            channels: [],
            presence: %Presence{},
            conn_pid: nil,
            callback_module: nil,
            init_channels: []
end
