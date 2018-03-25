alias Pushex.Structs.{SocketInfo, Options, Url}

defmodule Pushex.Structs.State do
  @moduledoc false
  defstruct app_key: "",
            channels: [],
            events: %{},
            socket_info: %SocketInfo{},
            options: %Options{},
            url: %Url{},
            conn_pid: nil
end
