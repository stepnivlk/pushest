defmodule Pushest.Supervisor do
  @moduledoc false

  alias Pushest.{Api, Socket}
  use Supervisor

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
