alias Pushex.Data.{SocketInfo, Options, Url}

defmodule Pushex.Data.State do
  @moduledoc false
  defstruct app_key: "",
            channels: %{},
            events: %{},
            socket_info: %SocketInfo{},
            options: %Options{},
            url: %Url{},
            conn_pid: nil,
            module: nil
end
