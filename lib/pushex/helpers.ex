defmodule Pushex.Helpers do
  @moduledoc false

  alias Pushex.Structs.{State, Options, SocketInfo}

  def auth(
    %State{
      app_key: app_key,
      options: %Options{secret: secret},
      socket_info: %SocketInfo{socket_id: socket_id}
    },
    channel
  ) do
    string_to_sign = "#{socket_id}:#{channel}"
    signature = :crypto.hmac(:sha256, secret, string_to_sign)
      |> Base.encode16
      |> String.downcase

    "#{app_key}:#{signature}"
  end

  @protocol 7
  def url(app_key, %Options{cluster: cluster, encrypted: encrypted}) do
    prefix = if encrypted, do: "wss", else: "ws"

    "#{prefix}://ws-#{cluster}.pusher.com/app/#{app_key}?protocol=#{@protocol}&client=pushex-elixir&version=0.1.0&flash=false"
  end
end
