defmodule Pushex.Data.Frame do
  @moduledoc false

  alias Pushex.Data.SubscriptionData

  defstruct [:channel, :event, :data]

  def subscribe(channel, auth, user_data) do
    %__MODULE__{
      event: "pusher:subscribe",
      data: %SubscriptionData{
        channel: channel,
        auth: auth
      }
    }
  end

  def unsubscribe(channel) do
    %__MODULE__{
      event: "pusher:subscribe",
      data: %SubscriptionData{
        channel: channel
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

  def encode!(frame = %__MODULE__{data: data}) do
    %{frame | data: %{frame.data | channel_data: Poison.encode!(data.channel_data)}}
    |> Poison.encode!()
  end

  def decode!(raw_frame) do
    Poison.decode!(raw_frame, as: %__MODULE__{})
  end
end
