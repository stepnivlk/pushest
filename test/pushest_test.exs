defmodule PushestTest do
  @moduledoc false

  use ExUnit.Case
  doctest Pushest

  import ExUnit.CaptureLog

  alias Pushest.FakeClient

  defmodule TestPushest do
    @moduledoc false

    use Pushest, otp_app: :pushest
  end

  def child_pid(mod_name) do
    Pushest.Supervisor
    |> Supervisor.which_children()
    |> Enum.find(fn {name, _, _, _} -> name == mod_name end)
    |> elem(1)
  end

  @app_key "PUSHER_APP_KEY"

  @pusher_config %{
    app_id: "PUSHER_APP_ID",
    key: @app_key,
    secret: "PUSHER_SECRET",
    cluster: "PUSHER_CLUSTER",
    encrypted: true
  }

  def start do
    {:ok, fake_client_pid} = FakeClient.start_link()
    {:ok, test_pushest_pid} = TestPushest.start_link(@pusher_config)
    Application.ensure_all_started(:pushest)

    api_pid = child_pid(Pushest.Api)
    socket_pid = child_pid(Pushest.Socket)

    FakeClient.establish_connection()

    [
      api_pid: api_pid,
      socket_pid: socket_pid,
      fake_client_pid: fake_client_pid,
      test_pushest_pid: test_pushest_pid
    ]
  end

  def wait_for_all(context) do
    :sys.get_state(context.socket_pid)
    :sys.get_state(context.api_pid)
    :sys.get_state(context.fake_client_pid)
    :sys.get_state(context.test_pushest_pid)

    :ok
  end

  setup_all do
    start()
  end

  describe "subscribe" do
    @channel "test-channel"
    test "to a public channel", context do
      TestPushest.subscribe(@channel)

      :sys.get_state(context.socket_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:payload] ==
               ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"test-channel","auth":null},"channel":null})

      assert TestPushest.subscribed_channels() |> Enum.member?(@channel)
    end

    @channel "private-channel"
    test "to a private channel", context do
      TestPushest.subscribe(@channel)

      :sys.get_state(context.socket_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:payload] ==
               ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"private-channel","auth":"#{
                 @app_key
               }:489cbc51261a2aa3baaf69b2df8c521530e2c1d9443d4cc3716328189120b1e8"},"channel":null})

      assert frame[:via] == :ws

      assert TestPushest.subscribed_channels() |> Enum.member?(@channel)
    end

    @channel "presence-fail-channel"
    test "to a presence channel without user_data", context do
      :sys.get_state(context.socket_pid)

      assert capture_log(fn ->
               TestPushest.subscribe(@channel)
             end) =~
               "#{@channel} is a presence channel and subscription must include channel_data"

      refute TestPushest.subscribed_channels() |> Enum.member?(@channel)
    end

    @channel "presence-pass-channel"
    test "to a presence channel with some user_data", context do
      TestPushest.subscribe(@channel, %{user_id: "1"})

      :sys.get_state(context.socket_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:payload] ==
               "{\"event\":\"pusher:subscribe\",\"data\":{\"channel_data\":\"{\\\"user_id\\\":\\\"1\\\"}\",\"channel\":\"#{
                 @channel
               }\",\"auth\":\"#{@app_key}:f57ab9a6a321361ee0594546da129d240b338c13ebac5444ccee4fbcbe80074f\"},\"channel\":null}"

      assert frame[:via] == :ws

      assert TestPushest.subscribed_channels() |> Enum.member?(@channel)
    end
  end

  @channel "private-subscribed-trigger-channel"
  describe "trigger on subscribed private channel" do
    setup do
      TestPushest.subscribe(@channel)
    end

    setup :wait_for_all

    @event "event"
    test "sends an event to a channel", context do
      TestPushest.trigger(@channel, @event, %{message: "message"})

      wait_for_all(context)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:via] == :ws

      assert frame[:payload] ==
               ~s({"event":"client-event","data":{"message":"message"},"channel":"#{@channel}"})
    end
  end

  @channel "public-subscribed-trigger-channel"
  describe "trigger on subscribed public channel" do
    setup do
      TestPushest.subscribe(@channel)
    end

    setup :wait_for_all

    @event "event"
    test "sends an event to a channel", context do
      TestPushest.trigger(@channel, @event, %{message: "message"})

      wait_for_all(context)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:via] == :api

      assert frame[:payload] ==
               "{\"name\":\"event\",\"data\":\"{\\\"message\\\":\\\"message\\\"}\",\"channel\":\"#{
                 @channel
               }\"}"

      ~s({"event":"client-event","data":{"message":"message"},"channel":"#{@channel}"})
    end
  end

  @channel "private-subscribed-trigger-channel-api"
  describe "trigger on subscribed channel forced via API" do
    setup do
      TestPushest.subscribe(@channel)
    end

    setup :wait_for_all

    @event "event"
    test "sends an event to a channel", context do
      TestPushest.trigger(@channel, @event, %{message: "message"}, force_api: true)

      :sys.get_state(context.api_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:via] == :api

      assert frame[:payload] ==
               "{\"name\":\"event\",\"data\":\"{\\\"message\\\":\\\"message\\\"}\",\"channel\":\"#{
                 @channel
               }\"}"

      assert frame[:path] ==
               '/apps/PUSHER_APP_ID/events?auth_key=PUSHER_APP_KEY&auth_timestamp=123&auth_version=1.0&body_md5=d1f9b8b45be3308f990149da9e0a5868&auth_signature=98b6de3c177e917375dc4e8a7cca9d2fb2be5cdd9fe61b0231853211cc0a452c'

      assert frame[:headers] == [
               {"content-type", "application/json"},
               {"X-Pusher-Library", "Pushest #{Mix.Project.config()[:version]}"}
             ]
    end
  end

  @channel "unsubscribed-trigger-channel"
  describe "trigger on unsubscribed channel" do
    @event "event"
    test "sends an event to an API endpoint", context do
      TestPushest.trigger(@channel, @event, %{message: "message"})

      :sys.get_state(context.api_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:via] == :api

      assert frame[:payload] ==
               "{\"name\":\"event\",\"data\":\"{\\\"message\\\":\\\"message\\\"}\",\"channel\":\"#{
                 @channel
               }\"}"

      assert frame[:path] ==
               '/apps/PUSHER_APP_ID/events?auth_key=PUSHER_APP_KEY&auth_timestamp=123&auth_version=1.0&body_md5=5ffd220c430c1e3e171458c14e9c3be9&auth_signature=ac41c93da2ae66aece34518f92b27386b92e19b628e78e2384460057c299f4ba'

      assert frame[:headers] == [
               {"content-type", "application/json"},
               {"X-Pusher-Library", "Pushest #{Mix.Project.config()[:version]}"}
             ]
    end
  end

  @channel "channels-map-channel"
  describe "channels" do
    setup do
      FakeClient.setup(%{channels: %{@channel => %{}}})
      :ok
    end

    setup :wait_for_all

    test "Returns map of all the subscribed channels" do
      assert TestPushest.channels() == %{"channels" => %{@channel => %{}}}

      {:ok, frame} = FakeClient.last_frame()

      assert frame[:via] == :api

      assert frame[:path] ==
               '/apps/PUSHER_APP_ID/channels?auth_key=PUSHER_APP_KEY&auth_timestamp=123&auth_version=1.0&body_md5=d41d8cd98f00b204e9800998ecf8427e&auth_signature=fc8411aa6951f2065c7e56ed91a465dc2666efc2e8d756dd1c1024e6c3cfe7ab'

      assert frame[:headers] == [
               {"X-Pusher-Library", "Pushest #{Mix.Project.config()[:version]}"}
             ]
    end
  end

  @channel "presence-list-channel"
  describe "presence" do
    setup do
      TestPushest.subscribe(@channel, %{user_id: "1", user_info: %{name: "Jose"}})
      FakeClient.reset_presence()
    end

    setup :wait_for_all

    test "Lists all conected users and keeps track of them", context do
      expected_presence = %Pushest.Socket.Data.Presence{
        count: 1,
        hash: %{"1" => %{"name" => "Jose"}},
        ids: ["1"],
        me: %{user_id: "1", user_info: %{name: "Jose"}}
      }

      :sys.get_state(context.socket_pid)

      assert TestPushest.presence() == expected_presence
    end
  end

  @channel "unsubscribe-subscribed-channel"
  describe "unsubscribe from subscribed channel" do
    setup do
      TestPushest.subscribe(@channel)
    end

    setup :wait_for_all

    test "unsubscribes and removes channel from local list", context do
      TestPushest.unsubscribe(@channel)

      :sys.get_state(context.socket_pid)

      refute TestPushest.subscribed_channels() == [@channel]
    end
  end
end
