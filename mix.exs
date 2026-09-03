defmodule MembraneVideoInterop.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/emerge-elixir/membrane_video_interop"

  def project do
    [
      app: :membrane_video_interop,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Membrane elements for VideoInterop CPU and zero-copy GPU frames",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: [
        main: "readme",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["README.md", "CHANGELOG.md", "LICENSE"]
      ],
      package: [
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => @source_url},
        files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:membrane_core, "~> 1.2"},
      {:membrane_raw_video_format, "~> 0.4"},
      {:video_interop, "~> 0.1.0"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end
end
