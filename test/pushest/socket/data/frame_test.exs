defmodule Pushest.Socket.Data.FrameTest do
  use ExUnit.Case, async: true
  doctest Pushest.Socket.Data.Frame

  alias Pushest.Socket.Data.Frame

  describe "encode!/1" do
    test "When `channel_data` is provided it should encode it as a string" do
      frame = %Frame{
        event: "pusher:subscribe",
        data: %Pushest.Socket.Data.SubscriptionData{
          auth: "auth",
          channel: "private-chnl",
          channel_data: %{
            user_id: 1,
            user_info: %{
              name: "Tomas Koutsky",
              email: "secret@secret.com"
            }
          }
        },
        channel: nil
      }

      expected_frame =
        "{\"event\":\"pusher:subscribe\",\"data\":{\"channel_data\":\"{\\\"user_info\\\":{" <>
          "\\\"name\\\":\\\"Tomas Koutsky\\\",\\\"email\\\":\\\"secret@secret.com\\\"}," <>
          "\\\"user_id\\\":1}\",\"channel\":\"private-chnl\",\"auth\":\"auth\"},\"channel\":null}"

      assert Frame.encode!(frame) == expected_frame
    end
  end
end
