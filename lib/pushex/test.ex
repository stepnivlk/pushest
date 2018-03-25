defmodule Pushex.Test do
  @moduledoc false

  def options do
    %{cluster: "eu", encrypted: true, secret: "442fb83444a53d33f3bf"}
  end

  def app_key, do: "92903f411439788e18e5"
end
