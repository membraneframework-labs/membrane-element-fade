defmodule Membrane.Element.Fade.InOut.Fading do
  alias Membrane.Time

  @enforce_keys [:to_level, :at_time]

  defstruct [
    to_level: nil,
    at_time: nil,
    duration: 500 |> Time.millisecond,
    tanh_arg_range: 3.5,
  ]

  # Fadings list element template
  @type t :: %Membrane.Element.Fade.InOut.Fading{
    to_level: nil | number,
    at_time: nil | Time.t,
    duration: Time.t,
    tanh_arg_range: number,
  }

end
