defmodule Pushest.Socket.Data.State do
  @moduledoc ~S"""
  Structure representing whole App state being held in GenServer process.
  """

  alias Pushest.Socket.Data.{SocketInfo, Url, Presence}
  alias Pushest.Data.Options

  defstruct url: %Url{},
            options: %Options{},
            socket_info: %SocketInfo{},
            channels: [],
            presence: %Presence{},
            conn_pid: nil,
            callback_module: nil,
            init_channels: []
end
