defmodule Pushex.Structs.Frame do
  @moduledoc false

  alias Pushex.Structs.SubscriptionData

  defstruct [:channel, :event, :data]

  def subscription(channel, auth, channel_data \\ nil) do
    %__MODULE__{
      event: "pusher:subscribe",
      data: %SubscriptionData{
        channel: channel,
        auth: auth,
        channel_data: channel_data
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
