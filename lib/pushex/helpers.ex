defmodule Pushex.Helpers do
  @moduledoc false

  alias Pushex.Data.{State, Options, SocketInfo, Url}

  def auth(%State{options: %Options{secret: nil}}, _channel), do: nil

  def auth(state, channel = "private-" <> _rest), do: do_auth(state, channel)

  def auth(state, channel = "presence-" <> _rest), do: do_auth(state, channel)

  def auth(_state, _channel), do: nil

  defp do_auth(
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

  @version Mix.Project.config()[:version]
  @protocol 7
  def url(app_key, %{cluster: cluster, encrypted: encrypted}) do
    %Url{
      domain: "ws-#{cluster}.pusher.com" |> to_charlist,
      path:
        "/app/#{app_key}?protocol=#{@protocol}&client=pushex&version=#{@version}&flash=false"
        |> to_charlist,
      port: if(encrypted, do: 443, else: 80)
    }
  end

  def validate_user_data(user_data = %{}), do: {:error, user_data}
  def validate_user_data(user_data = %{user_id: nil}), do: {:error, user_data}
  def validate_user_data(user_data = %{user_id: ""}), do: {:error, user_data}
  def validate_user_data(user_data = %{user_id: _}), do: {:ok, user_data}
end
