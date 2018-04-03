defmodule Pushest.Api.Data.Frame do
  @moduledoc ~S"""
  Structure representing a Frame being passed between Pushest and Pusher server.
  Includes methods constructing Frame structure for various pusher events.
  This module handles encode/decode actions for a Frame.
  """

  defstruct [:channel, :name, :data]

  @spec event(String.t(), String.t(), term) :: %__MODULE__{}
  def event(channel, event, data) do
    %__MODULE__{
      channel: channel,
      name: event,
      data: data
    }
  end

  @spec encode!(%__MODULE__{}) :: String.t()
  def encode!(frame = %__MODULE__{data: data}) do
    %{frame | data: Poison.encode!(data)}
    |> Poison.encode!()
  end

  def encode!(frame = %__MODULE__{}) do
    Poison.encode!(frame)
  end
end
