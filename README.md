# Pushex

## Usage
```elixir
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

# App usage:
{:ok, pid} = SimpleClient.start_link(app_key, options)

SimpleClient.subscribe(pid, "my-channel")

# Private channels are also supported:
# Please note, secret has to be provided and client events needs to be enabled
# in Pusher app settings.
SimpleClient.subscribe(pid, "private-channel")

SimpleClient.trigger(pid, "my-channel", "first-event", %{name: "Tomas Koutsky"})

# When "first-event" callback is being triggered:
# %Pushex.Data.Frame{
#   channel: "private-test",
#   data: "{\r\n  \"name\": \"John\",\r\n  \"message\": \"Hello\"\r\n}",
#   event: "first-event"
# }
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pushex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pushex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pushex](https://hexdocs.pm/pushex).

