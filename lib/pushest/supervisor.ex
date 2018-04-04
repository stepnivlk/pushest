defmodule Pushest.Supervisor do
  @moduledoc false

  alias Pushest.{Api, Socket}
  use Supervisor

  def start_link(pusher_opts, opts \\ []) do
    Supervisor.start_link(__MODULE__, pusher_opts)
  end

  def init(args) do
    children = [
      {Api, args},
      {Socket, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def config(module, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    app_config  = Application.get_env(otp_app, module, [])

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
