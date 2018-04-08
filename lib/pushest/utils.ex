defmodule Pushest.Utils do
  @moduledoc ~S"""
  Top-level utility/helpers module.
  """

  @doc ~S"""
  Tries to call given function with arguments on given module.
  Used when some frame is received at a `Socket` to pass that frame to user-defined
  module (where Pushest is being `use`d).
  """
  @spec try_callback(module, atom, list) :: term
  def try_callback(module, function, args) do
    apply(module, function, args)
  catch
    :error, payload ->
      stacktrace = System.stacktrace()
      reason = Exception.normalize(:error, payload, stacktrace)
      {:"$EXIT", {reason, stacktrace}}

    :exit, payload ->
      {:"$EXIT", payload}
  end
end
