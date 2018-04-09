# Pushest

Pushest is bidirectional Pusher client leveraging Elixir/OTP to combine server and client-side
Pusher features together in one library. Pushest communicates both via WebSockets and REST API.
You can trigger on any channel, subscribe to channels, handle events using callbacks or
keep track of presence.

[![Build Status](https://travis-ci.org/stepnivlk/pushest.svg?branch=master)](https://travis-ci.org/stepnivlk/pushest) [![Ebert](https://ebertapp.io/github/stepnivlk/pushest.svg)](https://ebertapp.io/github/stepnivlk/pushest)

Please note, this library is **BETA**

## TODO
- [x] Event scoping
- [x] Presence
- [x] Unsubscribe method
- [x] Channels list method
- [x] Auth token generated only for private/presence channels
- [x] Missing tests
- [x] Handle `pusher:error`
- [x] Generate documentation
- [x] :gun.conn monitoring
- [x] start_link/3 - opts to Pushest
- [x] Named process option
- [x] Propagate app version to url
- [ ] Overall error handling
- [x] Publish to hex.pm
- [x] Fallback to REST when triggering on a public channel
- [ ] Test recovery from :gun_down / EXIT
- [ ] expose `auth` function to generate a token for client-side libraries.
- [ ] trigger batching
- [ ] Push notifications
- [ ] Subscribe to a list of channels after startup

## Usage
### A simple implementation in an OTP application would be:
```elixir
# Add necessary pusher configuration to your application config:
# simple_client/config/config.exs
config :simple_client, SimpleClient,
  pusher_app_id: System.get_env("PUSHER_APP_ID"),
  pusher_key: System.get_env("PUSHER_APP_KEY"),
  pusher_secret: System.get_env("PUSHER_SECRET"),
  pusher_cluster: System.get_env("PUSHER_CLUSTER"),
  pusher_encrypted: true

# simple_client/simple_client.ex
defmodule SimpleClient do
  use Pushest, otp_app: :simple_client

  # handle_event/2 is user-defined callback which is triggered whenever an event
  # occurs on the channel.
  def handle_event({:ok, "public-channel", "some-event"}, frame) do
    # do something with public frame
  end

  def handle_event({:ok, "private-channel", "some-other-event"}, frame) do
    # do something with private frame
  end
  
  # We can also catch errors.
  def handle_event({:error, msg}, frame) do
    # do something with error
  end
end

# Now you can start your application with Pushest as a part of your supervision tree:
# simple_client/lib/simple_client/application.ex
def start(_type, _args) do
  children = [
    {SimpleClient, []}
  ]

  opts = [strategy: :one_for_one, name: Sup.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### You can also provide Pusher options directly via start_link/1 (without using OTP app configuration):
```elixir
config = %{
  app_id:  System.get_env("PUSHER_APP_ID"),
  key: System.get_env("PUSHER_APP_KEY"),
  secret: System.get_env("PUSHER_SECRET"),
  cluster: System.get_env("PUSHER_CLUSTER"),
  encrypted: true
}

{:ok, pid} = SimpleClient.start_link(config)
```

### Now you can use various functions injected in your module
```elixir
SimpleClient.subscribe("public-channel")
:ok
# ...
SimpleClient.subscribe("private-channel")
:ok
# ...
SimpleClient.subscribe("presence-channel", %{user_id: "1", user_info: %{name: "Tomas"}})
:ok
# ...
SimpleClient.presence()
%Pushest.Data.Presence{
  count: 2,
  hash: %{"1" => %{"name" => "Tomas"}, "2" => %{"name" => "Jose"}},
  ids: ["1", "2"],
  me: %{user_id: "1", user_info: %{name: "Tomas"}}
}
# ...
SimpleClient.trigger("private-channel", "first-event", %{message: "Ahoj"})
:ok
# ...
SimpleClient.channels()
["presence-channel", "private-channel", "public-channel"]
# ...
SimpleClient.unsubscribe("public-channel")
:ok
```

### Functions list
#### subscribe/1
Subscribes to public or private channel
```elixir
SimpleClient.subscribe("public-channel")
:ok
```

#### subscribe/2
Subscribes to private or presence channel with user data as second parameter.
User data has to contain `user_id` key with unique identifier for current user.
Can optionally contain `user_info` field with map of additional informations about user.
```elixir
user_data = %{user_id: 123, user_info: %{name: "Tomas", email: "secret@secret.com"}}
SimpleClient.subscribe("presence-channel", user_data)
:ok
# ...
SimpleClient.subscribe("private-channel", user_data)
:ok
```

#### trigger/3
Triggers on given channel and event with given data payload. Pushest sends data by
default to REST API endpoint of Pusher, however when subscribed to private or presence channel
it sends data to Pusher via WebSockets.
```elixir
SimpleClient.trigger("public-channel", "event", %{message: "message"})
:ok
# ..
SimpleClient.trigger("private-channel", "event", %{message: "message"})
:ok
```

#### trigger/4
Same as `trigger/3` but lets you force trigger over the REST API (so it never triggers via WebSockets).
```elixir
SimpleClient.trigger("private-channel", "event", %{message: "message"}, force_api: true)
```

#### channels/0
Returns map of all the active channels which are being used in your Pusher application.
Can contain informations about subscribed users.
```elixir
SimpleClient.channels()
%{"channels" => %{"public-channel" => %{}, "private-channel" => %{}}}
```

#### subscribed_channels/0
Returns list of all the subscribed channels for current instance.
```elixir
SimpleClient.channels()
["private-channel"]
```

#### presence/0
Returns information about all the users subscribed to a presence channel.
```elixir
SimpleClient.presence()
%Pushest.Data.Presence{
  count: 2,
  hash: %{"1" => %{"name" => "Tomas"}, "2" => %{"name" => "Jose"}},
  ids: ["1", "2"],
  me: %{user_id: "2", user_info: %{name: "Jose"}}
}
```

#### unsubscribe/1
Unsubscribes from given channel
```elixir
SimpleClient.unsubscribe("public-channel")
```

#### `frame` example
`frame` is a `Pushest.Socket.Data.Frame` or `Pushest.Api.Data.Frame` struct with data payload as a map. 
```elixir
%Pushest.Data.Frame{
  channel: "private-channel",
  data: %{"name" => "John", "message" => "Hello"},
  event: "second-event"
}
```

## Installation

The package can be installed by adding `pushest` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pushest, "~> 0.2.0"}
  ]
end
```

## Documentation

Documentation can be be found at [https://hexdocs.pm/pushest](https://hexdocs.pm/pushest).
