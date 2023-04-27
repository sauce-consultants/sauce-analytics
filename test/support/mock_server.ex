defmodule MockServer do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: MockServer.Router, options: [port: 8081]}
    ]

    Supervisor.init(children, strategy: :one_for_one, name: MockServer.Supervisor)
  end
end
