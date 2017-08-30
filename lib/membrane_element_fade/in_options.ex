defmodule Membrane.Element.Fade.In.Options do
  alias Membrane.Time
  defstruct fade_duration: 3 |> Time.second, countdown: 0 |> Time.second
end