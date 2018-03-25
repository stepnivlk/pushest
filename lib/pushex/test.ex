defmodule Pushex.Test do
  @moduledoc false

  use Pushex

  @app_key "92903f411439788e18e5"
  @options %{cluster: "eu", encrypted: true, secret: "442fb83444a53d33f3bf"}

  def start_link() do
    Pushex.start_link(@app_key, @options, __MODULE__)
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
