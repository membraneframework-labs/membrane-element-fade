defmodule Membrane.Element.Fade.Fading do
  @moduledoc """
  Defines struct describing a single fading.
  """

  alias Membrane.Time

  @enforce_keys [:to_level, :at_time]

  defstruct to_level: nil,
            at_time: nil,
            duration: 500 |> Time.millisecond(),
            tanh_arg_range: 3.5

  @typedoc """
  Struct describing a single fading:
  - `to_level` - Volume level expected after the fading. Can be specified as
    a non-negative number, with 0 being a muted signal, and 1 being 100% loudness.
    Values greater than 1 amplify the signal and may cause clipping.
  - `at_time` - Time (counted from the beginning of stream) when the fading
    should occur.
  - `duration` - Time of the fading.
  - `tanh_arg_range` - Each fading changes volume according to the
    [hyperbolic tangent](https://www.wolframalpha.com/input/?i=tanh(x))
    function and this field specifies the range of its arguments to be applied,
    interpreted as `[-tanh_arg_range, tanh_arg_range]`. Generally speaking,
    decreasing this value without changing the `:duration` should give a feeling
    of more gentle slope, while increasing it should make fade function more
    steep in the middle of duration.
  """
  @type t :: %__MODULE__{
          to_level: number,
          at_time: Time.t(),
          duration: Time.t(),
          tanh_arg_range: number
        }
end
