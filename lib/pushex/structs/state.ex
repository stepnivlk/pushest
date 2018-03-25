alias Pushex.Structs.{SocketInfo, Options}

defmodule Pushex.Structs.State do
  @moduledoc false
  defstruct app_key: "", channels: [], socket_info: %SocketInfo{}, options: %Options{}
end
