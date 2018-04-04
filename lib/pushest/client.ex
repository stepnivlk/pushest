defmodule Pushest.Client do
  @moduledoc false

  def for_env do
    if Mix.env == :test do
      Pushest.FakeClient
    else
      :gun
    end
  end
end
