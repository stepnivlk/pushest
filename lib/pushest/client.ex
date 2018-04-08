defmodule Pushest.Client do
  @moduledoc ~S"""
  Returns `:gun` or `Pushest.FakeClient` based on current environment.
  """

  def for_env do
    if Application.get_env(:pushest, :fake_all) do
      Pushest.FakeClient
    else
      :gun
    end
  end
end
