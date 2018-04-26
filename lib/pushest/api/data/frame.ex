defmodule Pushest.Api.Data.Frame do
  @moduledoc ~S"""
  Structure representing a Frame being passed between Pushest and Pusher server.
  Includes methods constructing Frame structure for various pusher events.
  This module handles encode/decode actions for a Frame.
  """

  @type t :: %__MODULE__{
          channel: String.t(),
          name: String.t(),
          data: map
        }

  defstruct [:channel, :name, :data]

  @doc ~S"""
  Creates a Frame struct representing an event being sent to the Pusher.

  ## Examples

      iex> Pushest.Api.Data.Frame.event("channel", "event", %{message: "message"})
      %Pushest.Api.Data.Frame{channel: "channel", name: "event", data: %{message: "message"}}
  """
  @spec event(String.t(), String.t(), term) :: %__MODULE__{}
  def event(channel, event, data) do
    %__MODULE__{
      channel: channel,
      name: event,
      data: data
    }
  end

  @doc ~S"""
  Encodes given frame as a JSON, if frame contains data map it encodes it first.
  Then encodes once more whole frame.

  ## Examples

      iex> Pushest.Api.Data.Frame.encode!(%Pushest.Api.Data.Frame{channel: "channel", name: "name"})
      ~s({"name":"name","data":"null","channel":"channel"})

      iex> Pushest.Api.Data.Frame.encode!(%Pushest.Api.Data.Frame{channel: "channel", name: "name", data: %{message: "message"}})
      "{\"name\":\"name\",\"data\":\"{\\\"message\\\":\\\"message\\\"}\",\"channel\":\"channel\"}"
  """
  @spec encode!(%__MODULE__{}) :: String.t()
  def encode!(frame = %__MODULE__{data: data}) do
    %{frame | data: Poison.encode!(data)}
    |> Poison.encode!()
  end

  def encode!(frame = %__MODULE__{}) do
    Poison.encode!(frame)
  end
end
