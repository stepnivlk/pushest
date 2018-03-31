defmodule PushestTest do
  use ExUnit.Case
  doctest Pushest

  import ExUnit.CaptureLog

  alias Pushest.FakeClient

  defmodule TestPushest do
    use Pushest
    @app_key "APP_KEY"
    @pusher_opts %{cluster: "eu", encrypted: true, secret: "SECRET"}

    def start_link() do
      Pushest.start_link(@app_key, @pusher_opts, __MODULE__)
    end
  end

  describe "subscribe" do
    setup do
      FakeClient.start_link()

      {:ok, pid} = TestPushest.start_link()

      FakeClient.setup(%{parent_pid: pid})

      [pid: pid]
    end

    @channel "test-channel"
    test "to a public channel", context do
      TestPushest.subscribe(context.pid, @channel)

      :sys.get_state(context.pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame ==
               ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"test-channel","auth":null},"channel":null})

      assert TestPushest.channels(context.pid) == [@channel]
    end

    @channel "private-channel"
    test "to a private channel", context do
      TestPushest.subscribe(context.pid, @channel)

      :sys.get_state(context.pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame ==
               ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"private-channel","auth":"APP_KEY:faf0cd4400fa3972e5a25ffc7f211bdc084c718182963ca918cdd1431e280ba3"},"channel":null})

      assert TestPushest.channels(context.pid) == [@channel]
    end

    @channel "presence-channel"
    test "to a presence channel without user_data", context do
      assert capture_log(fn ->
               TestPushest.subscribe(context.pid, @channel)
             end) =~
               "#{@channel} is a presence channel and subscription must include channel_data"

      assert TestPushest.channels(context.pid) == []
    end

    @channel "presence-channel"
    test "to a presence channel with some user_data", context do
      TestPushest.subscribe(context.pid, @channel, %{user_id: "1"})

      :sys.get_state(context.pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame ==
               "{\"event\":\"pusher:subscribe\",\"data\":{\"channel_data\":\"{\\\"user_id\\\":\\\"1\\\"}\",\"channel\":\"presence-channel\",\"auth\":\"APP_KEY:57586a1149033a465694c3ad1bd43f28e0c49c6ecbecc36e8f03374afe7416ff\"},\"channel\":null}"

      assert TestPushest.channels(context.pid) == [@channel]
    end
  end

  @channel "test-channel"
  describe "trigger" do
    setup do
      FakeClient.start_link()

      {:ok, pid} = TestPushest.start_link()

      FakeClient.setup(%{parent_pid: pid})

      TestPushest.subscribe(pid, @channel)

      [pid: pid]
    end

    @event "event"
    test "sends an event to a channel", context do
      TestPushest.trigger(context.pid, @channel, @event, %{message: "message"})

      :sys.get_state(context.pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame == ~s({"event":"client-event","data":{"message":"message"},"channel":"test-channel"})
    end
  end

  @channel "presence-channel"
  describe "presence" do
    setup do
      FakeClient.start_link()

      {:ok, pid} = TestPushest.start_link()

      FakeClient.setup(%{parent_pid: pid})

      TestPushest.subscribe(pid, @channel, %{user_id: "1", user_info: %{name: "Jose"}})

      :timer.sleep(500)

      [pid: pid]
    end

    test "Lists all conected users and keeps track of them", context do
      expected_presence =  %Pushest.Data.Presence{
        count: 1,
        hash: %{"1" => %{"name" => "Jose"}},
        ids: ["1"],
        me: %{user_id: "1", user_info: %{name: "Jose"}}
      }

      assert TestPushest.presence(context.pid) == expected_presence
    end
  end

  @channel "test-channel"
  describe "unsubscribe" do
    setup do
      FakeClient.start_link()

      {:ok, pid} = TestPushest.start_link()

      FakeClient.setup(%{parent_pid: pid})

      TestPushest.subscribe(pid, @channel)
      :sys.get_state(pid)

      [pid: pid]
    end

    test "unsubscribes and removes channel from local list", context do
      TestPushest.unsubscribe(context.pid, @channel)

      :sys.get_state(context.pid)

      refute TestPushest.channels(context.pid) == [@channel]
    end
  end
end
