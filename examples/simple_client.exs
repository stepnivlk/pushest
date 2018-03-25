defmodule SimpleClient do
  @moduledoc false

  use Pushex

  def start_link(app_key, options) do
    Pushex.Socket.start_link(app_key, options, __MODULE__)
  end

  def handle_event({"first-event", frame}) do
    IO.inspect(frame)
    {:noreply, frame}
  end

  def handle_event({"second-event", frame}) do
    IO.inspect(frame)
    {:noreply, frame}
  end
end

# Config:
app_key = Application.get_env(:simple_client, :pusher_app_key)
secret = Application.get_env(:simple_client, :pusher_secret)
cluster = Application.get_env(:simple_client, :pusher_cluster)

options = %{cluster: cluster, encrypted: true, secret: secret}

# Initialization:
{:ok, pid} = SimpleClient.start_link(app_key, options)

# Subscription to a channel:
SimpleClient.subscribe(pid, "my-channel")

# Private channels are also supported:
# Please note, secret has to be provided and client events needs to be enabled
# in Pusher app settings.
SimpleClient.subscribe(pid, "private-channel")

# Triggers can be performed only on private channels:
SimpleClient.trigger(pid, "private-channel", "first-event", %{name: "Tomas Koutsky"})

# When "first-event" callback is being triggered:
# %Pushex.Data.Frame{
#   channel: "private-test",
#   data: "{\r\n  \"name\": \"John\",\r\n  \"message\": \"Hello\"\r\n}",
#   event: "first-event"
# }
