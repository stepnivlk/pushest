defmodule Pushest.Api.Timestamp do
  @moduledoc false

  @constant_timestamp 123

  def for_env do
    if Mix.env() == :test do
      @constant_timestamp
    else
      DateTime.to_unix(DateTime.utc_now())
    end
  end
end
