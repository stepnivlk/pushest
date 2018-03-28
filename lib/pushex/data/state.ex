defmodule Pushex.Data.State do
  @moduledoc ~S"""
  Structure representing whole App state being held in GenServer process.
  """

  alias Pushex.Data.{SocketInfo, Options, Url, Presence}

  defstruct app_key: "",
            channels: [],
            socket_info: %SocketInfo{},
            options: %Options{},
            presence: %Presence{},
            url: %Url{},
            conn_pid: nil,
            module: nil
end
