defmodule Membrane.Element.Fade.Mixfile do
  use Mix.Project

  def project do
    [app: :membrane_element_fade,
     compilers: Mix.compilers,
     version: "0.0.1",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Membrane Multimedia Framework (Fade Element)",
     maintainers: ["Jacek Fidos"],
     licenses: ["LGPL"],
     name: "Membrane Element: Fade",
     source_url: "https://github.com/membraneframework/membrane-element-fade",
     preferred_cli_env: [espec: :test],
     deps: deps()]
  end


  def application do
    [applications: [
      :membrane_core
    ], mod: {Membrane.Element.Fade, []}]
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib",]


  defp deps do
    [
      {:membrane_core, git: "git@github.com:membraneframework/membrane-core.git", branch: "v0.2"},
      {:membrane_caps_audio_raw, git: "git@github.com:membraneframework/membrane-caps-audio-raw.git"},
    ]
  end
end
