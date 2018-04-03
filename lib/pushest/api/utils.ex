defmodule Pushest.Api.Utils do
  @moduledoc false

  alias Pushest.Api.Data.Url

  @auth_version 1.0

  def url(%{cluster: cluster, encrypted: encrypted}) do
    %Url{
      domain: to_charlist("api-#{cluster}.pusher.com"),
      port: if(encrypted, do: 443, else: 80)
    }
  end

  def full_path("POST", path, frame, %{app_id: app_id, key: key, secret: secret}) do
    auth_timestamp = DateTime.to_unix(DateTime.utc_now())

    frame_md5 = :crypto.hash(:md5, frame) |> Base.encode16(case: :lower)

    string_to_sign =
      "POST\n/apps/#{app_id}/#{path}\n" <>
        "auth_key=#{key}&" <>
        "auth_timestamp=#{auth_timestamp}&" <>
        "auth_version=#{@auth_version}&" <> "body_md5=#{frame_md5}"

    auth_signature = :crypto.hmac(:sha256, secret, string_to_sign) |> Base.encode16(case: :lower)

    "/apps/#{app_id}/#{path}?" <>
      "auth_key=#{key}&" <>
      "auth_timestamp=#{auth_timestamp}&" <>
      "auth_version=#{@auth_version}&" <>
      "body_md5=#{frame_md5}" <> "&auth_signature=#{auth_signature}"
  end
end
