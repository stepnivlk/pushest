defmodule Pushex.Structs.SocketInfo do
  @moduledoc false

  defstruct [:socket_id, :activity_timeout]

  def decode!(raw_frame) do
    Poison.decode!(raw_frame, as: %__MODULE__{})
  end
end
