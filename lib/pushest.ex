defmodule Pushest do
  @moduledoc ~S"""
  Pushest handles communication with Pusher server via wesockets. Abstracts
  un/subscription, client-side triggers, private/presence channel authorizations.
  Keeps track of subscribed channels and users presence when subscribed to presence channel.
  Pushest is meant to be used in your module where you can define callbacks for
  events you're interested in.

  A simple implementation would be:
  ```
  defmodule SimpleClient do
    use Pushest

    def start_link() do
      options = %{
        cluster: "eu",
        encrypted: true,
        secret: "SECRET"
      }
      Pushest.start_link("APP_KEY", options, __MODULE__, name: __MODULE__)
    end

    def handle_event({:ok, "public-channel", "some-event"}, frame) do
      # do something with public frame
    end

    def handle_event({:ok, "private-channel", "some-other-event"}, frame) do
      # do something with private frame
    end
  end
  ```
  """

  @typedoc ~S"""
  Options for Pushest to properly communicate with Pusher server.

  - `:cluster` - Cluster where your Pusher app is configured.
  - `:encrypted` - When set to true communication with Pusher is fully encrypted.
  - `:secret` - Necessary to subscribe to private/presence channels and trigger events.
  """
  @type pusher_opts :: %{cluster: String.t(), encrypted: boolean, secret: String.t()}

  require Logger

  alias Pushest.Client

  @client Application.get_env(:pushest, :conn_client)

  @doc ~S"""
  Invoked when the Pusher event occurs (e.g. other client sends a message).
  """
  @callback handle_event({atom, String.t(), String.t()}, term) :: term

  defmacro __using__(_opts) do
    quote do
      @behaviour Pushest

      def subscribe(pid, channel, user_data) do
        GenServer.cast(pid, {:subscribe, channel, user_data})
      end

      def subscribe(pid, channel) when is_pid(pid) do
        GenServer.cast(pid, {:subscribe, channel, %{}})
      end

      def subscribe(channel, user_data) do
        GenServer.cast(__MODULE__, {:subscribe, channel, user_data})
      end

      def subscribe(channel) do
        GenServer.cast(__MODULE__, {:subscribe, channel, %{}})
      end

      def trigger(pid, channel, event, data) do
        GenServer.cast(pid, {:trigger, channel, event, data})
      end

      def trigger(channel, event, data) do
        Client.send({:trigger, channel, event, data}, __MODULE__)
      end

      def channels(pid) do
        GenServer.call(pid, :channels)
      end

      def channels do
        GenServer.call(__MODULE__, :channels)
      end

      def presence(pid) do
        GenServer.call(pid, :presence)
      end

      def presence do
        GenServer.call(__MODULE__, :presence)
      end

      def unsubscribe(pid, channel) do
        GenServer.cast(pid, {:unsubscribe, channel})
      end

      def unsubscribe(channel) do
        GenServer.cast(__MODULE__, {:unsubscribe, channel})
      end

      def handle_event({status, channel, event}, frame) do
        require Logger

        Logger.error(
          "No #{inspect(status)} handle_event/2 clause in #{__MODULE__} provided for #{
            inspect(event)
          }"
        )
      end

      defoverridable handle_event: 2
    end
  end

  @doc ~S"""
  Starts a Pushest process linked to current process.
  Please note, you need to provide a module as a third element, Pushest will try
  to invoke `handle_event` callbacks in that module when Pusher event occurs.

  For available pusher_opts values see `t:pusher_opts/0`.
  """
  @spec start_link(pusher_opts, module, list) :: {:ok, pid} | {:error, term}
  def start_link(pusher_opts, module, opts \\ []) do
    Pushest.Supervisor.start_link(pusher_opts)
  end

  @spec try_callback(module, atom, list) :: term
  defp try_callback(module, function, args) do
    apply(module, function, args)
  catch
    :error, payload ->
      stacktrace = System.stacktrace()
      reason = Exception.normalize(:error, payload, stacktrace)
      {:"$EXIT", {reason, stacktrace}}

    :exit, payload ->
      {:"$EXIT", payload}
  end
end
