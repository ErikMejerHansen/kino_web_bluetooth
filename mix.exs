defmodule KinoWebBluetooth.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_web_bluetooth,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd npm install --prefix js"],
      test: ["test", "cmd npm test --prefix js"],
      compile: ["compile"],
      "compile.web": ["cmd npm run build --prefix js"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {KinoWebBluetooth.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:kino, "~> 0.13.2"}
    ]
  end
end
