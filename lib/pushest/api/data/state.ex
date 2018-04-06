defmodule Pushest.Api.Data.State do
  @moduledoc false

  alias Pushest.Api.Data.Url
  alias Pushest.Data.Options

  defstruct url: %Url{}, options: %Options{}, conn_pid: nil
end
