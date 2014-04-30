defmodule ExtendUnit.Mixfile do
  use Mix.Project

  def project do
    [app: :extend_unit,
     version: "0.0.1",
     elixir: "~> 0.13.0",
     deps: deps]
  end

  def application do
    [ applications: [],
      mod: {ExtendUnit, []} ]
  end

  defp deps do
    [ {:meck, github: "eproxus/meck"} ]
  end
end
