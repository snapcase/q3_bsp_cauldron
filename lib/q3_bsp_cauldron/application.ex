defmodule Q3BspCauldron.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Q3BspCauldron.BSPMonitor,
      {Plug.Cowboy, scheme: :http, plug: Q3BspCauldron.Router, options: [port: 4000]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Q3BspCauldron.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
