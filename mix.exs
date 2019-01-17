defmodule Membrane.Element.Fade.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane-element-fade"

  def project do
    [
      app: :membrane_element_fade,
      compilers: Mix.compilers(),
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane Multimedia Framework (Fade Element)",
      package: package(),
      name: "Membrane Element: Fade",
      source_url: @github_url,
      docs: docs(),
      deps: deps()
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Proprietary"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.Element.Fade.App, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:membrane_core, "~> 0.2.1"},
      {:membrane_caps_audio_raw, "~> 0.1"},
      {:bunch, "~> 0.2"}
    ]
  end
end
