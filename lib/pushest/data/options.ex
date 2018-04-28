defmodule Pushest.Data.Options do
  @moduledoc ~S"""
  Structure representing main Pusher options which are passed via Pushest
  initializating methods.
  """

  alias Pushest.Adapters.{Api, Socket}

  @type t :: %__MODULE__{
          app_id: String.t(),
          key: String.t(),
          cluster: String.t(),
          secret: String.t(),
          encrypted: boolean,
          api_adapter: module,
          socket_adapter: module
        }

  defstruct app_id: "",
            key: "",
            cluster: "",
            encrypted: false,
            secret: "",
            api_adapter: Api,
            socket_adapter: Socket
end
