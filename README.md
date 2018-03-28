# Pushest

[![Build Status](https://travis-ci.org/stepnivlk/pushest.svg?branch=master)](https://travis-ci.org/stepnivlk/pushest) [![Ebert](https://ebertapp.io/github/stepnivlk/pushest.svg)](https://ebertapp.io/github/stepnivlk/pushest)

**WIP**

## TODO
- [x] Event scoping
- [x] Presence
- [x] Unsubscribe method
- [x] Channels list method
- [x] Auth token generated only for private/presence channels
- [ ] Tests
- [x] Handle `pusher:error`
- [ ] Documentation
- [ ] :gun.conn supervision
- [x] start_link/3 - opts to Pushest
- [x] Named process option
- [x] Propagate app version to url
- [ ] Overall error handling
- [ ] Start unlinked
- [x] Publish to hex.pm
- [ ] Fallback to REST when triggering on a public channel

## Usage
```elixir
defmodule SimpleClient do
  use Pushest

  def start_link(app_key, app_options, options \\ []) do
    Pushest.start_link(app_key, app_options, __MODULE__, options)
  end
  
  # User-defined event handling callbacks.
  def handle_event({:ok, "public-channel", "first-event"}, frame) do
    # Process frame here
  end

  def handle_event({:ok, "private-channel", "second-event"}, frame) do
    # Process frame here
  end
  
  # In case when there is an error on event. We can catch error message.
  def handle_event({:error, msg}, frame) do
    # Process error here
  end
end

# Config:
app_key = System.get_env("PUSHER_APP_KEY")
secret = System.get_env("PUSHER_SECRET")
cluster = System.get_env("PUSHER_CLUSTER")

options = %{cluster: cluster, encrypted: true, secret: secret}

# Initialization:
{:ok, pid} = SimpleClient.start_link(app_key, options)

# Subscription to public channel:
SimpleClient.subscribe(pid, "public-channel")

# Subscription to private channel:
# Please note, secret has to be provided and client events needs to be enabled
# in Pusher app settings.
SimpleClient.subscribe(pid, "private-channel")

# Subscription to presence channel:
# `:user_id` is mandatory and has to be unique over the userset in given channel.
SimpleClient.subscribe(pid, "presence-channel", %{user_id: "1", user_info: %{name: "Tomas Koutsky"}})

# Get list of users subscribed to a presence-channel:
SimpleClient.presence(pid)
# => %Pushest.Data.Presence{
#      count: 1,
#      hash: %{"1" => %{"name" => "Tomas Koutsky"}},
#      ids: ["1"],
#      me: %{user_id: "1", user_info: %{name: "Tomas Koutsky"}}
#    }

# Triggers can be performed only on private channels:
SimpleClient.trigger(pid, "private-channel", "first-event", %{name: "Tomas Koutsky"})

# List of subscribed channels:
SimpleClient.channels(pid)
# => ["presence-channel", "private-channel", "public-channel"]

# Unsubscribe from a channel:
SimpleClient.unsubscribe(pid, "public-channel")
```

## Usage with registered name
```elixir
defmodule NamedClient do
  use Pushest

  def start_link(app_key, app_options) do
    Pushest.start_link(app_key, app_options, __MODULE__, name: __MODULE__)
  end
  
  def handle_event({:ok, "public-channel", "first-event"}, frame) do
    # Process frame here
  end

  def handle_event({:ok, "private-channel", "second-event"}, frame) do
    # Process frame here
  end
  
  def handle_event({:error, msg}, frame) do
    # Process error here
  end
end

# Config:
app_key = System.get_env("PUSHER_APP_KEY")
secret = System.get_env("PUSHER_SECRET")
cluster = System.get_env("PUSHER_CLUSTER")

options = %{cluster: cluster, encrypted: true, secret: secret}

# Initialization:
NamedClient.start_link(app_key, options)

NamedClient.subscribe("public-channel")
NamedClient.subscribe("private-channel")

NamedClient.subscribe(pid, "presence-channel", %{user_id: "2", user_info: %{name: "Jose Valim"}})
NamedClient.presence()
# => %Pushest.Data.Presence{
#      count: 2,
#      hash: %{"1" => %{"name" => "Tomas Koutsky"}, "2" => %{"name" => "Jose Valim"}},
#      ids: ["1", "2"],
#      me: %{user_id: "2", user_info: %{name: "Jose Valim"}}
#    }

NamedClient.trigger("private-channel", "first-event", %{name: "Tomas Koutsky"})

NamedClient.channels()
# => ["presence-channel", "private-channel", "public-channel"]

NamedClient.unsubscribe("public-channel")
```

#### `frame` example
`frame` is a `Pushest.Data.Frame` struct with data payload as a map. 
```elixir
%Pushest.Data.Frame{
  channel: "private-channel",
  data: %{"name" => "John", "message" => "Hello"},
  event: "second-event"
}
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pushest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pushest, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pushest](https://hexdocs.pm/pushest).
