defmodule Pushest.Adapter do
  @moduledoc ~S"""
  Defines a public intefrace which should all the adapters follow.
  """

  @type call_resp :: map | list(String.t()) | :no_data | :error

  @callback call(Pushest.Router.call_term()) :: call_resp
  @callback cast(Pushest.Router.cast_term()) :: :ok
end
