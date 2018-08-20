defmodule SknBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :skn_bot,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:skn_lib, git: "git@gitlab.com:tr.hoan00/skn_lib.git", branch: "master"},
      {:ecto, "~> 2.2"},
      {:uuid, "~> 1.1"}
    ]
  end
end
