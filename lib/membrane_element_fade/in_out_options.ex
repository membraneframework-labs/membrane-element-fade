defmodule Membrane.Element.Fade.InOut.Options do
	alias Membrane.Time
  defstruct fadings_list: [%{to_level: 1, at_time: 0, duration: 500 |> Time.millisecond}], initial_level: 0
end