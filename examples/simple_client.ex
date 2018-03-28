defmodule Pushest.SimpleClient do
  @moduledoc false

  use Pushest

  def options() do
    secret = System.get_env("PUSHER_SECRET")
    cluster = System.get_env("PUSHER_CLUSTER")

    %{cluster: cluster, encrypted: true, secret: secret}
  end

  def app_key() do
    System.get_env("PUSHER_APP_KEY")
  end

  def start_link() do
    Pushest.start_link(app_key(), options(), __MODULE__, name: __MODULE__)
  end

  def handle_event({:ok, "public-channel", "first-event"}, frame) do
    # Process frame here
    IO.inspect(frame)
  end

  def handle_event({:ok, "private-channel", "second-event"}, frame) do
    # Process frame here
    IO.inspect(frame)
  end

  # In case when there is an error on event. We can catch error message.
  def handle_event({:error, _msg}, frame) do
    # Process error here
    IO.inspect(frame)
  end
end
