defmodule Pushest.Socket.UtilsTest do
  use ExUnit.Case, async: true
  doctest Pushest.Socket.Utils

  alias Pushest.Socket.Utils
  alias Pushest.Socket.Data.{Url, State, SocketInfo}
  alias Pushest.Data.Options

  @app_key "APP_KEY"

  describe "auth/3" do
    @state_with_secret %State{
      options: %Options{key: @app_key, secret: "SECRET"},
      socket_info: %SocketInfo{socket_id: "123.456"}
    }

    @state_without_secret %State{
      options: %Options{key: @app_key},
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
               "APP_KEY:25da2ccb93072680b122bed5006f0ca35e3334c6c9b3e0244d10928437d821e2"
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
  describe "url/2" do
    test "Encrypted connection" do
      options = %{key: @app_key, cluster: "eu", encrypted: true}

      assert %Url{domain: domain, path: path, port: port} = Utils.url(options)
      assert domain == 'ws-eu.pusher.com'

      assert path ==
               to_charlist(
                 "/app/APP_KEY?protocol=7&client=pushest&version=#{@version}&flash=false"
               )

      assert port == 443
    end

    test "Non-encrypted connection" do
      options = %{key: @app_key, cluster: "us", encrypted: false}

      assert %Url{domain: domain, path: path, port: port} = Utils.url(options)
      assert domain == 'ws-us.pusher.com'

      assert path ==
               to_charlist(
                 "/app/APP_KEY?protocol=7&client=pushest&version=#{@version}&flash=false"
               )

      assert port == 80
    end
  end
end
