defmodule Pushest.Supervisor do
  @moduledoc ~S"""
  Supervises Api and Socket processes, handles generation of proper configuration
  for those modules.
  """

  alias Pushest.{Api, Socket}
  use Supervisor

  @spec start_link(map, module) :: {:ok, pid} | {:error, term}
  def start_link(pusher_opts, callback_module) do
    Supervisor.start_link(__MODULE__, {pusher_opts, callback_module}, name: __MODULE__)
  end

  def init(opts) do
    children = [
      {Api, opts},
      {Socket, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @type pusher_opts :: %{
          app_id: String.t(),
          secret: String.t(),
          key: String.t(),
          cluster: String.t(),
          encrypted: boolean
        }

  @doc ~S"""
  Fetches necessary Pusher configuration from a host OTP application config.
  Returs that configuration without `pusher_` prefix.
  """
  def config(module, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    app_config = Application.get_env(otp_app, module, [])

    pusher_config = %{
      app_id: app_config[:pusher_app_id],
      key: app_config[:pusher_key],
      secret: app_config[:pusher_secret],
      cluster: app_config[:pusher_cluster],
      encrypted: app_config[:pusher_encrypted]
    }

    pusher_config
  end
end
