# Membrane.Element.Fade

This element applies fading curves to the stream, performing fade in and fade out operations.

## Installation

Add the following line to your `deps` in `mix.exs`.  Run `mix deps.get`.

```elixir
{:membrane_element_fade, github: "membraneframework/membrane-element-fade"}
```

## Sample Usage

```elixir
defmodule Fade.Pipeline do
  alias Membrane.Element.{Fade, File}
  alias Fade.Fading
  alias Membrane.Pipeline.Spec
  alias Membrane.Time
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do

    fade = %Fade{
      fadings: [
        %Fading{to_level: 1, at_time: 0, duration: 2 |> Time.second(), tanh_arg_range: 0.5},
        %Fading{to_level: 0, at_time: 2 |> Time.second(), duration: 3 |> Time.second()},
        %Fading{to_level: 0.5, at_time: 6 |> Time.second(), duration: 3 |> Time.second()},
        %Fading{
          to_level: 1,
          at_time: 10 |> Time.second(),
          duration: 3 |> Time.second(),
          tanh_arg_range: 5
        },
        %Fading{to_level: 0, at_time: 15 |> Time.second(), duration: 10 |> Time.second()}
      ],
      initial_volume: 0,
      step_time: 2 |> Time.milliseconds()
    }

    children = [
      file_src: %File.Source{location: "in.raw"},
      fade: fade,
      file_sink: %File.Sink{location: "out.raw"}
    ]

    links = %{
      {:file_src, :output} => {:fade, :input},
      {:fade, :output} => {:file_sink, :input}
    }

    {{:ok, %Spec{children: children, links: links}}, %{}}
  end
end

```
