defmodule Membrane.Element.Fade.InOut.Options do
  alias Membrane.Element.Fade.InOut
  defstruct fadings_list: [%InOut{to_level: 1, at_time: 0}], initial_volume: 0
  @type t :: %InOut.Options{
    initial_volume: number,
    fadings_list: list(InOut.t)
  }
end