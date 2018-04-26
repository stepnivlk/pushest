defmodule Pushest.Socket.Data.Frame do
  @moduledoc ~S"""
  Structure representing a Frame being passed between Pushest and Pusher server.
  Includes methods constructing Frame structure for various pusher events.
  This module handles encode/decode actions for a Frame.
  """

  alias Pushest.Socket.Data.SubscriptionData

  @type t :: %__MODULE__{
    channel: String.t(),
    event: String.t(),
    data: map
  }

  defstruct [:channel, :event, :data]

  @doc ~S"""
  Returns Frame struct representing subscribe event being sent to the Pusher.

  ## Examples

      iex> Pushest.Socket.Data.Frame.subscribe("private-chnl", "auth")
      %Pushest.Socket.Data.Frame{
        event: "pusher:subscribe",
        data: %Pushest.Socket.Data.SubscriptionData{
          auth: "auth",
          channel: "private-chnl",
          channel_data: %{}
        },
        channel: nil
      }

      iex> Pushest.Socket.Data.Frame.subscribe("private-chnl", "auth", %{user_id: 1})
      %Pushest.Socket.Data.Frame{
        event: "pusher:subscribe",
        data: %Pushest.Socket.Data.SubscriptionData{
          auth: "auth",
          channel: "private-chnl",
          channel_data: %{user_id: 1}
        },
        channel: nil
      }
  """
  @spec subscribe(String.t(), String.t() | nil, map) :: %__MODULE__{}
  def subscribe(channel, auth, user_data \\ %{}) do
    %__MODULE__{
      event: "pusher:subscribe",
      data: %SubscriptionData{
        channel: channel,
        auth: auth,
        channel_data: user_data
      }
    }
  end

  @doc ~S"""
  Returns Frame struct representing unsubscribe event being sent to the Pusher.

  ## Examples

      iex> Pushest.Socket.Data.Frame.unsubscribe("private-chnl")
      %Pushest.Socket.Data.Frame{
        event: "pusher:unsubscribe",
        data: %Pushest.Socket.Data.SubscriptionData{channel: "private-chnl"}
      }
  """
  @spec unsubscribe(String.t()) :: %__MODULE__{}
  def unsubscribe(channel) do
    %__MODULE__{
      event: "pusher:unsubscribe",
      data: %SubscriptionData{
        channel: channel
      }
    }
  end

  @doc ~S"""
  Returns Frame struct representing an event being sent to the Pusher.

  ## Examples

      iex> Pushest.Socket.Data.Frame.event("private-chnl", "evnt", %{name: "stepnivlk"})
      %Pushest.Socket.Data.Frame{
        channel: "private-chnl",
        data: %{name: "stepnivlk"},
        event: "client-evnt"
      }
  """
  @spec event(String.t(), String.t(), term) :: %__MODULE__{}
  def event(channel, event, data) do
    %__MODULE__{
      channel: channel,
      event: "client-#{event}",
      data: data
    }
  end

  @doc ~S"""
  Encodes Frame struct to stringified JSON.

  ## Examples

      iex> Pushest.Socket.Data.Frame.encode!(%Pushest.Socket.Data.Frame{
      ...> channel: "public-channel", event: "first-event"
      ...> })
      "{\"event\":\"first-event\",\"data\":null,\"channel\":\"public-channel\"}"

      iex> Pushest.Socket.Data.Frame.encode!(%Pushest.Socket.Data.Frame{
      ...> channel: "public-channel",
      ...> event: "first-event",
      ...> data: %{name: "stepnivlk"}
      ...> })
      "{\"event\":\"first-event\",\"data\":{\"name\":\"stepnivlk\"},\"channel\":\"public-channel\"}"
  """
  @spec encode!(%__MODULE__{}) :: String.t()
  def encode!(frame = %__MODULE__{data: %SubscriptionData{channel_data: channel_data}}) do
    %{frame | data: %{frame.data | channel_data: Poison.encode!(channel_data)}}
    |> Poison.encode!()
  end

  def encode!(frame = %__MODULE__{}) do
    Poison.encode!(frame)
  end

  @doc ~S"""
  Decodes frame from stringified JSON to Frame struct.

  ## Examples

      iex> Pushest.Socket.Data.Frame.decode!("{\"event\":\"first-event\",\"data\":null,\"channel\":\"public-channel\"}")
      %Pushest.Socket.Data.Frame{channel: "public-channel", event: "first-event"}

      iex> Pushest.Socket.Data.Frame.decode!("{\"event\":\"first-event\",\"data\":{\"test\":1},\"channel\":\"public-channel\"}")
      %Pushest.Socket.Data.Frame{channel: "public-channel", event: "first-event", data: %{"test" => 1}}
  """
  @spec decode!(String.t()) :: %__MODULE__{}
  def decode!(raw_frame) do
    frame = Poison.decode!(raw_frame, as: %__MODULE__{})
    %{frame | data: decode_data!(frame.data)}
  end

  def decode_data!(data) when is_map(data), do: data
  def decode_data!(nil), do: nil
  def decode_data!(data), do: Poison.decode!(data)
end
