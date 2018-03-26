# Pushex

[![Ebert](https://ebertapp.io/github/stepnivlk/pushex.svg)](https://ebertapp.io/github/stepnivlk/pushex)

**WIP**

## TODO
- [x] Event scoping
- [ ] Presence
- [x] usubscribe
- [x] channels
- [x] Don't generate auth for public channels
- [ ] Tests
- [x] Handle `pusher:error`
- [ ] Documentation
- [ ] :gun.conn supervision
- [x] start_link/3 - opts to Pushex
- [x] Named process
- [x] Propagate app version to url
- [ ] Overall error handling
- [ ] Publish to hex.pm

## Usage
```elixir
defmodule SimpleClient do
  @moduledoc false

  use Pushex

  def start_link(app_key, app_options, options \\ []) do
    Pushex.start_link(app_key, app_options, __MODULE__, options)
  end

  # Global event handling callbacks. Gets triggered whenever
  # there is a given event on any subscribed channel
  def handle_event({:ok, "first-event"}, frame) do
    # Process frame here
    {:ok, frame}
  end

  def handle_event({:ok, "second-event"}, frame) do
    # Process frame here
    {:ok, frame}
  end
  
  # Local event handling callback. Scoped to specific channel name.
  def handle_event({:ok, "private-channel", "second-event"}, frame) do
    # Process frame here
    {:ok, frame}
  end
  
  # In case when there is an error on event. We can catch error message.
  def handle_event({:error, msg}) do
    # Process error here
    {:error, msg}
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
