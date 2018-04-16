defmodule Pushest do
  @moduledoc ~S"""
  Pushest is a Pusher library leveraging Elixir/OTP to combine server and client-side Pusher features.
  Abstracts un/subscription, client-side triggers, private/presence channel authorizations.
  Keeps track of subscribed channels and users presence when subscribed to a presence channel.
  Pushest is meant to be `use`d in your module where you can define callbacks for
  events you're interested in.

  A simple implementation in an OTP application would be:
  ```
  # Add necessary pusher configuration to your application config (assuming an OTP app):
  # simple_client/config/config.exs
  config :simple_client, SimpleClient,
    pusher_app_id: System.get_env("PUSHER_APP_ID"),
    pusher_key: System.get_env("PUSHER_APP_KEY"),
    pusher_secret: System.get_env("PUSHER_SECRET"),
    pusher_cluster: System.get_env("PUSHER_CLUSTER"),
    pusher_encrypted: true

  # simple_client/simple_client.ex
  defmodule SimpleClient do
    # :otp_app option is needed for Pushest to get a config.
    use Pushest, otp_app: :simple_client

    # Subscribe to these channels right after application startup.
    def init_channels do
      [
        [name: "public-init-channel", user_data: %{}],
        [name: "private-init-channel", user_data: %{}],
        [name: "presence-init-channel", user_data: %{user_id: 123}],
      ]
    end

    # handle incoming events.
    def handle_event({:ok, "public-init-channel", "some-event"}, frame) do
      # do something with public-init-channel frame
    end

    def handle_event({:ok, "public-channel", "some-event"}, frame) do
      # do something with public-channel frame
    end

    def handle_event({:ok, "private-channel", "some-other-event"}, frame) do
      # do something with private-channel frame
    end
  end

  # Now you can start your application as a part of your supervision tree:
  # simple_client/lib/simple_client/application.ex
  def start(_type, _args) do
    children = [
      {SimpleClient, []}
    ]

    opts = [strategy: :one_for_one, name: Sup.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

  You can also provide Pusher options directly via start_link/1 (without using OTP app configuration):
  ```
  config = %{
    app_id:  System.get_env("PUSHER_APP_ID"),
    key: System.get_env("PUSHER_APP_KEY"),
    secret: System.get_env("PUSHER_SECRET"),
    cluster: System.get_env("PUSHER_CLUSTER"),
    encrypted: true
  }

  {:ok, pid} = SimpleClient.start_link(config)
  ```

  Now you can interact with Pusher using methods injected in your module:
  ```
  SimpleClient.trigger("private-channel", "event", %{message: "via api"}) 
  SimpleClient.channels()
  # => %{
  "channels" => %{
    "presence-init-channel" => %{},
    "private-init-channel" => %{},
    "public-init-channel" => %{}
  }
  SimpleClient.subscribe("private-channel")
  SimpleClient.trigger("private-channel", "event", %{message: "via ws"}) 
  SimpleClient.trigger("private-channel", "event", %{message: "via api"}, force_api: true) 
  # ...
  ```
  For full list of injected methods please check the README.
  """

  alias Pushest.Router

  @doc ~S"""
  Invoked when the Pusher event occurs (e.g. other client sends a message).
  """
  @callback handle_event({atom, String.t(), String.t()}, term) :: term

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @typedoc ~S"""
      Options for Pushest to properly communicate with Pusher server.

      - `:app_id` - Pusher Application ID.
      - `:key` - Pusher Application key.
      - `:secret` - Necessary to subscribe to private/presence channels and trigger events.
      - `:cluster` - Cluster where your Pusher app is configured.
      - `:encrypted` - When set to true communication with Pusher is fully encrypted.
      """
      @type pusher_opts :: %{
              app_id: String.t(),
              secret: String.t(),
              key: String.t(),
              cluster: String.t(),
              encrypted: boolean
            }

      @typedoc ~S"""
      Optional options for trigger function.

      - `:force_api` - Always triggers via Pusher REST API endpoint when set to `true`
      """
      @type trigger_opts :: [force_api: boolean]

      @behaviour Pushest

      @config Pushest.Supervisor.config(__MODULE__, opts)

      @doc ~S"""
      Starts a Pushest Supervisor process linked to current process.
      Can be started as a part of host application supervision tree.
      Pusher options can be passed as an argument or can be provided in an OTP
      application config.

      For available pusher_opts values see `t:pusher_opts/0`.
      """
      def start_link(pusher_opts) when is_map(pusher_opts) do
        Pushest.Supervisor.start_link(pusher_opts, __MODULE__, init_channels())
      end

      def start_link(_) do
        Pushest.Supervisor.start_link(@config, __MODULE__, init_channels())
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc ~S"""
      Subscribe to a channel with user_data as a map. When subscribing to a
      presence- channel user_id key with unique identifier as a value has to be
      provided in the user_data map. user_info key can contain a map with optional
      informations about user.
      E.g.: %{user_id: "1", user_info: %{name: "Tomas Koutsky"}}
      """
      def subscribe(channel, user_data) do
        Router.cast({:subscribe, channel, user_data})
      end

      @doc ~S"""
      Subscribe to a channel without any user data, like any public channel.
      """
      def subscribe(channel) do
        Router.cast({:subscribe, channel, %{}})
      end

      @doc ~S"""
      Trigger on given channel/event combination - sends given data to Pusher.
      data has to be a map.
      """
      def trigger(channel, event, data) do
        Router.cast({:trigger, channel, event, data})
      end

      @doc ~S"""
      Same as trigger/3 but adds a possiblity to enforce triggering via API endpoint.
      For enforced API trigger provide `force_api: true` as an `opts`.
      E.g.: `Mod.trigger("channel", "event", %{message: "m"}, force_api: true)`

      For trigger_opts values see `t:trigger_opts/0`.
      """
      def trigger(channel, event, data, opts) do
        Router.cast({:trigger, channel, event, data}, opts)
      end

      @doc ~S"""
      Returns all the channels anyone is using, calls Pusher via REST API.
      """
      def channels do
        Router.call(:channels)
      end

      @doc ~S"""
      Returns only the channels this client is subscribed to.
      """
      def subscribed_channels do
        Router.call(:subscribed_channels)
      end

      @doc ~S"""
      Returns information about all the users subscribed to a presence channels
      this client is subscribed to.
      """
      def presence do
        Router.call(:presence)
      end

      @doc ~S"""
      Unsubscribes from a channel
      """
      def unsubscribe(channel) do
        Router.cast({:unsubscribe, channel})
      end

      @doc ~S"""
      Function meant to be overwritten in user module, e.g.:
      ```
      defmodule MyMod do
        use Pushest, otp_app: :my_mod

        def init_channels do
          [
            [name: "public-init-channel", user_data: %{}],
            [name: "private-init-channel", user_data: %{}],
            [name: "presence-init-channel", user_data: %{user_id: 123}],
          ]
        end
      end
      ```
      Subscribes to given list of channels right after application startup.
      Each element has to be a keyword list in exact format of:
      [name: String.t(), user_data: map]
      """
      def init_channels do
        []
      end

      @doc ~S"""
      Function meant to be overwritten in user module, e.g.:
      ```
      defmodule MyMod do
        use Pushest, otp_app: :my_mod

        handle_event({:ok, "my-channel, "my-event"}, frame) do
          # Do something with a frame here.
        end
      end
      ```
      Catches events sent to a channels the client is subscribed to.
      """
      def handle_event({status, channel, event}, frame) do
        require Logger

        Logger.error(
          "No #{inspect(status)} handle_event/2 clause in #{__MODULE__} provided for #{
            inspect(event)
          }"
        )
      end

      defoverridable handle_event: 2, init_channels: 0
    end
  end
end
