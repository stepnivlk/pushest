defmodule Pushest.Api.Utils do
  @moduledoc ~S"""
  Various Api-scoped utilities.
  """

  alias Pushest.Api.Data.Url
  alias Pushest.Api.Timestamp

  @auth_version 1.0

  @doc ~S"""
  Returns url struct for given arguments.

  ## Examples

      iex> Pushest.Api.Utils.url(%{cluster: "eu", encrypted: true})
      %Pushest.Api.Data.Url{domain: 'api-eu.pusher.com', port: 443}

      iex> Pushest.Api.Utils.url(%{cluster: "us", encrypted: false})
      %Pushest.Api.Data.Url{domain: 'api-us.pusher.com', port: 80}
  """
  def url(%{cluster: cluster, encrypted: encrypted}) do
    %Url{
      domain: to_charlist("api-#{cluster}.pusher.com"),
      port: if(encrypted, do: 443, else: 80)
    }
  end

  @doc ~S"""
  Generates a full path for given verb/path by adding all the necessary auth_
  parameters to properly authorize against Pusher API.

  ## Examples

      iex> Pushest.Api.Utils.full_path("POST", "events", %{app_id: "app_id", key: "key", secret: "secret"}, "frame")
      "/apps/app_id/events?auth_key=key&auth_timestamp=123&auth_version=1.0&body_md5=dcf3e36ee8115282aad46485cab6a4be&auth_signature=5ed16e8f17bcd3d0a750e64af8a5c751949c4f52fb32b9d2dc8f2a0f618a79c0"

      iex> Pushest.Api.Utils.full_path("GET", "events", %{app_id: "app_id", key: "key", secret: "secret"})
      "/apps/app_id/events?auth_key=key&auth_timestamp=123&auth_version=1.0&body_md5=d41d8cd98f00b204e9800998ecf8427e&auth_signature=7e4ff0027ba406a0c638ee08967c9d6e8d2e2485020e31a25118b57f5b50239a"
  """
  def full_path(verb, path, %{app_id: app_id, key: key, secret: secret}, frame \\ "") do
    auth_timestamp = Timestamp.for_env()

    frame_md5 = :crypto.hash(:md5, frame) |> Base.encode16(case: :lower)

    string_to_sign =
      "#{verb}\n/apps/#{app_id}/#{path}\n" <>
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
