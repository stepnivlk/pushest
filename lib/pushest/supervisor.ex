defmodule Pushest.Supervisor do
  @moduledoc false

  alias Pushest.{Api, Socket}
  use Supervisor

  def start_link(pusher_opts) do
    Supervisor.start_link(__MODULE__, pusher_opts)
  end

  def init(args) do
    children = [
      {Api, args},
      {Socket, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
