defmodule PushestTest do
  use ExUnit.Case
  doctest Pushest

  alias Pushest.FakeClient

  defmodule TestPushest do
    use Pushest
    @app_key "APP_KEY"
    @pusher_opts %{cluster: "eu", encrypted: true, secret: "SECRET"}

    def start_link() do
      Pushest.start_link(@app_key, @pusher_opts, __MODULE__)
    end
  end

  setup do
    FakeClient.start_link()

    {:ok, pid} = TestPushest.start_link()

    [pid: pid]
  end

  describe "subscribe" do
    test "Subscribing to a public channel", context do
      TestPushest.subscribe(context.pid, "test-channel")
      :timer.sleep(1000)

      {:ok, frame} = FakeClient.last_frame()
      assert frame == ~s({"event":"pusher:subscribe","data":{"channel_data":"{}","channel":"test-channel","auth":null},"channel":null})
    end
  end
end
