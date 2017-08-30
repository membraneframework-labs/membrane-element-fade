defmodule Membrane.Element.Fade.InOut.Options do
  alias Membrane.Time
  defstruct fade_in_duration: 3 |> Time.second, fade_in_start: 0 |> Time.second, fade_out_start: 3 |> Time.second, fade_out_duration: 3 |> Time.second
end