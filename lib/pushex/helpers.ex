defmodule Pushex.Helpers do
  @moduledoc false

  alias Pushex.Data.{State, Options, SocketInfo, Url}

  def auth(
        %State{
          app_key: app_key,
          options: %Options{secret: secret},
          socket_info: %SocketInfo{socket_id: socket_id}
        },
        channel
      ) do
    string_to_sign = "#{socket_id}:#{channel}"

    signature =
      :crypto.hmac(:sha256, secret, string_to_sign)
      |> Base.encode16()
      |> String.downcase()

    "#{app_key}:#{signature}"
  end

  @protocol 7
  def url(app_key, %{cluster: cluster, encrypted: encrypted}) do
    %Url{
      domain: "ws-#{cluster}.pusher.com" |> to_charlist,
      path: "/app/#{app_key}?protocol=#{@protocol}&client=pushex&version=0.1.0&flash=false" |> to_charlist,
      port: (if encrypted, do: 443, else: 80)
    }
  end
end
