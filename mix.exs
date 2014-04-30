defmodule ExtendUnit.Mixfile do
  use Mix.Project

  def project do
    [app: :extend_unit,
     version: "0.0.1",
     elixir: "~> 0.13.0",
     elixirc_options: [debug_info: true],
     deps: deps]
  end

  def application do
    [ applications: [],
      mod: {ExtendUnit, []} ]
  end

  defp deps do
    [ {:meck, github: "extend-unit/meck"} ]
  end
end
