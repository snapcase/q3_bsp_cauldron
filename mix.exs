defmodule Q3BspCauldron.MixProject do
  use Mix.Project

  def project do
    [
      app: :q3_bsp_cauldron,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Q3BspCauldron.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.18"},
      {:plug_cowboy, "~> 2.7"},
      {:file_system, "~> 1.1"}
    ]
  end
end
