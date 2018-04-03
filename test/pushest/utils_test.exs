defmodule Pushest.UtilsTest do
  use ExUnit.Case, async: true
  doctest Pushest.Utils

  alias Pushest.Utils
  alias Pushest.Data.{Url, Options, State, SocketInfo}

  @app_key "APP_KEY"

  describe "auth/3" do
    @state_with_secret %State{
      app_key: @app_key,
      options: %Options{secret: "SECRET"},
      socket_info: %SocketInfo{socket_id: "123.456"}
    }

    @state_without_secret %State{
      app_key: @app_key,
      options: %Options{},
      socket_info: %SocketInfo{socket_id: "123.456"}
    }

    test "Missing secret in options" do
      assert Utils.auth(@state_with_secret, "channel", %{}) == nil
    end

    test "Public Channel" do
      assert Utils.auth(@state_with_secret, "channel", %{}) == nil
    end

    test "Private Channel with missing secret" do
      assert Utils.auth(@state_without_secret, "channel", %{}) == nil
    end

    test "Private Channel with empty user_data" do
      assert Utils.auth(@state_with_secret, "private-channel", %{}) ==
               "APP_KEY:6429ffe6128abf74b8a970fa816118023aa19f7d28e38169e289b44fa591f340"
    end

    test "Private Channel with user_data" do
      user_data = %{user_id: 123}

      assert Utils.auth(@state_with_secret, "private-channel", user_data) ==
               "APP_KEY:50dc812246ca0aa4d4f8122299ee17120112a07874a2490bf9776a26ceec188e"
    end

    test "Presence Channel with user_data" do
      user_data = %{
        user_id: 123,
        user_info: %{name: "Tomas Koutsky", email: "valid@valid.com"}
      }

      assert Utils.auth(@state_with_secret, "presence-channel", user_data) ==
               "APP_KEY:5791979a4d81085a1c45835b34ab18c7047418c41668f840f0b40a4c1d17ecf0"
    end
  end

  @version Mix.Project.config()[:version]
  describe "ws_url/2" do
    test "Encrypted connection" do
      options = %{cluster: "eu", encrypted: true}

      assert %Url{domain: domain, path: path, port: port} = Utils.ws_url(@app_key, options)
      assert domain == 'ws-eu.pusher.com'

      assert path ==
               to_charlist(
                 "/app/APP_KEY?protocol=7&client=pushest&version=#{@version}&flash=false"
               )

      assert port == 443
    end

    test "Non-encrypted connection" do
      options = %{cluster: "us", encrypted: false}

      assert %Url{domain: domain, path: path, port: port} = Utils.ws_url(@app_key, options)
      assert domain == 'ws-us.pusher.com'

      assert path ==
               to_charlist(
                 "/app/APP_KEY?protocol=7&client=pushest&version=#{@version}&flash=false"
               )

      assert port == 80
    end
  end
end
