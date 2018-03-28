defmodule Pushest.Data.SocketInfo do
  @moduledoc ~S"""
  Structure representing a basic socket informations which are being sent when
  connection with Pusher server is estabilished.
  This module handles decode action for a SocketInfo.
  """

  defstruct [:socket_id, :activity_timeout]

  @doc ~S"""
  Decodes frame from stringified JSON to SocketInfo struct.

  ## Examples

      iex> Pushest.Data.SocketInfo.decode(%{"socket_id" => "123.456", "activity_timeout" => 120})
      %Pushest.Data.SocketInfo{socket_id: "123.456", activity_timeout: 120}
  """
  @spec decode(map) :: %__MODULE__{}
  def decode(socket_info) do
    %__MODULE__{
      socket_id: socket_info["socket_id"],
      activity_timeout: socket_info["activity_timeout"]
    }
  end
end
