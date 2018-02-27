defmodule Membrane.Element.Fade.InOut.Options do
  alias Membrane.Element.Fade.InOut
  alias Membrane.Time

  defstruct [
    fadings: [],
    initial_volume: 0,
    step_time: 5 |> Time.milliseconds,
  ]

  @type t :: %InOut.Options{
    initial_volume: number,
    fadings: list(InOut.Fading.t),
    step_time: Time.t,
  }

end
