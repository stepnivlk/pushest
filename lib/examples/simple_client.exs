defmodule SimpleClient do
  @moduledoc false

  use Pushex

  @app_key "92903f411439788e18e5"
  @options %{cluster: "eu", encrypted: true, secret: "442fb83444a53d33f3bf"}

  def start_link(app_key, options) do
    Pushex.Socket.start_link(@app_key, @options, __MODULE__)
  end

  def handle_event({"first-event", frame}) do
    IO.inspect frame
    {:noreply, frame}
  end

  def handle_event({"second-event", frame}) do
    IO.inspect frame
    {:noreply, frame}
  end
end

# Config:
app_key = Application.get_env(:simple_client, :pusher_app_key)
secret = Application.get_env(:simple_client, :pusher_secret)
cluster = Application.get_env(:simple_client, :pusher_cluster)

options = %{cluster: cluster, encrypted: true, secret: secret}

# App usage:
{:ok, pid} = SimpleClient.start_link(app_key, options)

SimpleClient.subscribe(pid, "my-channel")

SimpleClient.trigger(pid, "my-channel", "first-event", %{name: "Tomas Koutsky"})

# When "second-event" callback is being triggered:
# %Pushex.Data.Frame{
#   channel: "private-test",
#   data: "{\r\n  \"name\": \"John\",\r\n  \"message\": \"Hello\"\r\n}",
#   event: "first-event"
# }