defmodule Membrane.Element.Fade.InOut.Options do
  alias Membrane.Element.Fade.InOut

  defstruct [
    fadings: [],
    initial_volume: 0,
  ]

  @type t :: %InOut.Options{
    initial_volume: number,
    fadings: list(InOut.Fading.t),
  }

end
