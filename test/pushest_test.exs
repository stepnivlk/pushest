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
    |> Enum.find(fn({name, _, _, _}) -> name == mod_name end)
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

  def start() do
    {:ok, fake_client_pid} = FakeClient.start_link()
    {:ok, test_pushest_pid} = TestPushest.start_link(@pusher_config)
    Application.ensure_all_started(:pushest)

    # :timer.sleep(500)

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

  setup_all do
    start()
  end

  describe "subscribe" do
    @channel "test-channel"
    test "to a public channel", context do
      TestPushest.subscribe(@channel)

      :sys.get_state(context.socket_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame ==
               ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"test-channel","auth":null},"channel":null})

      assert TestPushest.subscribed_channels() |> Enum.member?(@channel)
    end

    @channel "private-channel"
    test "to a private channel", context do
      TestPushest.subscribe(@channel)

      :sys.get_state(context.socket_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame ==
               ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"private-channel","auth":"#{@app_key}:489cbc51261a2aa3baaf69b2df8c521530e2c1d9443d4cc3716328189120b1e8"},"channel":null})

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

      assert frame ==
               "{\"event\":\"pusher:subscribe\",\"data\":{\"channel_data\":\"{\\\"user_id\\\":\\\"1\\\"}\",\"channel\":\"#{@channel}\",\"auth\":\"#{@app_key}:f57ab9a6a321361ee0594546da129d240b338c13ebac5444ccee4fbcbe80074f\"},\"channel\":null}"

      assert TestPushest.subscribed_channels() |> Enum.member?(@channel)
    end
  end

  @channel "test-channel"
  describe "trigger" do
    setup context do
      TestPushest.subscribe(@channel)
      :sys.get_state(context.socket_pid)
      :sys.get_state(context.api_pid)
      :sys.get_state(context.fake_client_pid)
      context
    end

    @event "event"
    test "sends an event to a channel", context do
      TestPushest.trigger(@channel, @event, %{message: "message"})

      :sys.get_state(context.socket_pid)

      {:ok, frame} = FakeClient.last_frame()

      assert frame ==
               ~s({"event":"client-event","data":{"message":"message"},"channel":"test-channel"})
    end
  end

  @channel "presence-list-channel"
  describe "presence" do
    setup context do
      TestPushest.subscribe(@channel, %{user_id: "1", user_info: %{name: "Jose"}})
      FakeClient.reset_presence()
      :sys.get_state(context.socket_pid)
      :sys.get_state(context.api_pid)
      :sys.get_state(context.fake_client_pid)
      context
    end

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

  @channel "unsubscribe-channel"
  describe "unsubscribe" do
    setup context do
      TestPushest.subscribe(@channel)
      :sys.get_state(context.socket_pid)
      :sys.get_state(context.api_pid)
      :sys.get_state(context.fake_client_pid)
      context
    end

    test "unsubscribes and removes channel from local list", context do
      TestPushest.unsubscribe(@channel)

      :sys.get_state(context.socket_pid)

      refute TestPushest.subscribed_channels() == [@channel]
    end
  end
end
