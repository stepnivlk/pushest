defmodule Pushex do
  @moduledoc false

  @callback handle_event({String.t, term}, term) :: {:ok, term}

  defmacro __using__(_opts) do
    quote do
      @behaviour Pushex

      def handle_event(event, _state) do
        raise "No handle_event/2 clause in #{__MODULE__} provided for #{inspect event}"
      end
    end
  end
end
