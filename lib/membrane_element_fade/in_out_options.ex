defmodule Membrane.Element.Fade.InOut.Options.ListType do
  alias Membrane.Time
  @enforce_keys [:to_level, :at_time]
  defstruct to_level: nil, at_time: nil, duration: 500 |> Time.millisecond, arg_range: 3.5
  # Fadings list element template
  @type t :: %Membrane.Element.Fade.InOut.Options.ListType{
    to_level: nil | number,
    at_time: nil | Time.t,
    duration: Time.t,
    arg_range: number
  }
end

defmodule Membrane.Element.Fade.InOut.Options do
  alias Membrane.Element.Fade.InOut
  defstruct fadings_list: [%InOut.Options.ListType{to_level: 1, at_time: 0}], initial_volume: 0
  @type t :: %InOut.Options{
    initial_volume: number,
    fadings_list: list(InOut.Options.ListType.t)
  }
end