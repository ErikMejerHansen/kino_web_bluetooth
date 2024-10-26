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
      # Running tsc first to avoid warning about empty "assets" folder
      "compile.web": [esbuild_command(), tailwind_command()],
      "compile.web.watch.ts": esbuild_command() <> " --watch",
      "compile.web.watch.css": tailwind_command() <> " --watch"
    ]
  end

  defp esbuild_command do
    "cmd --cd js npx esbuild src/main.ts* --outfile=../assets/main.js --bundle --format=esm"
  end

  defp tailwind_command do
    "cmd --cd js npx tailwindcss -i ./src/main.css -o ../assets/main.css"
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
