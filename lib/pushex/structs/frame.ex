defmodule Pushex.Structs.Frame do
  @moduledoc false

  defstruct [:channel, :event, :data]

  def subscription(channel, auth) do
    %__MODULE__{
      event: "pusher:subscribe",
      data: %{
        channel: channel,
        auth: auth
      }
    }
  end

  def event(channel, event, data) do
    %__MODULE__{
      channel: channel,
      event: "client-#{event}",
      data: data
    }
  end

  def encode!(frame), do: Poison.encode!(frame)

  def decode!(raw_frame) do
    Poison.decode!(raw_frame, as: %__MODULE__{})
  end
end
