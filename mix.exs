defmodule KinoWebBluetooth.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ErikMejerHansen/kino_web_bluetooth"

  def project do
    [
      app: :kino_web_bluetooth,
      version: @version,
      description: "Web Bluetooth (BLE GATT) Smart Cell and API for Livebook",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      mod: {KinoWebBluetooth.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:kino, "~> 0.13"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
