defmodule Pushest.Api.Timestamp do
  @moduledoc ~S"""
  Returns current unix timestamp or static one based on current environment.
  """

  @constant_timestamp 123

  def for_env do
    if Application.get_env(:pushest, :fake_all) do
      @constant_timestamp
    else
      DateTime.to_unix(DateTime.utc_now())
    end
  end
end
