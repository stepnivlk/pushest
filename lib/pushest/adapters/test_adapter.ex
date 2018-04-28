defmodule Pushest.Adapters.TestAdapter do
  @moduledoc ~S"""
  Adapter meant to be used in tests.
  """

  @behaviour Pushest.Adapter

  def call(_command) do
    :no_data
  end

  def cast(_command) do
    :ok
  end
end
