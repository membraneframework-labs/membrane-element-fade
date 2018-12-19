# Membrane.Element.Fade

This element applies fading curves to the data, performing fade in and fade out operations.

# Usage
## Installation

Add the following line to your `deps` in `mix.exs`.  Run `mix deps.get`.

```elixir
{:membrane_element_fade, github: "membraneframework/membrane-element-fade"}
```


## Fade.InOut
### Options
This module's options consist of:

#### initial volume
The fader performs all-time multiplication of the signal. `:initial_volume` is an indication of how loud it should be at start. It can be specified as non-negative number, with 0 being a muted signal, and 1 being 100% loudness. Values greater than 1 amplify the signal and may cause clipping.
#### step_time
Step time determines length of each chunk having equal volume level while fading.
#### fadings
`:fadings` is a list containing `Fade.InOut.Fading` structs, which specify fade parameters over time. They consist of following keys:
##### `:to_level`
This key specifies how loud should the signal be at the end of described fade. Requirements and further description are similar to those of `initial volume`.
It is advised to never specify two neighbouring fades with the same levels.
Last specified fade's level will persist the element's loudness level until the program is stopped.
Required.
##### `:at_time`
When the fade should start, given in Membrane.Time units.
However, a fade will not start until the previous one has ended.
The fades should be specified in the same order as they are intended to be performed.
Required.
##### `:duration`
Time between start and finish of the fade, given in Membrane.Time units. Default 500 ms.
##### `:tanh_arg_range`
An optional key that specifies +/- range of argument of tanh(x) function which is used for fading. If specified, it should be a positive number. Generally speaking, decreasing this keys' value without changing the `:duration` should give a feeling of more gentle slope, while increasing it should make fade function more steep in the middle of duration. Default 3.

Correctly specified options could like like this:
```elixir
alias Membrane.Element.Fade.InOut.{Options, Fading}
alias Membrane.Time

%Options{
  fadings_list: [
    %Fading{to_level: 1, at_time: 0, duration: 2 |> Time.second, arg_range: 0.5},
    %Fading{to_level: 0, at_time: 2 |> Time.second, duration: 3 |> Time.second},
    %Fading{to_level: 0.5, at_time: 6 |> Time.second, duration: 3 |> Time.second},
    %Fading{to_level: 1, at_time: 10 |> Time.second, duration: 3 |> Time.second, tanh_arg_range: 5},
    %Fading{to_level: 0, at_time: 15 |> Time.second, duration: 10 |> Time.second},
  ],
  initial_volume: 0,
  step_time: 2 |> Time.milliseconds,
}
```

# License

[LGPLv3](https://www.gnu.org/licenses/lgpl-3.0.en.html).


# Authors

* Jacek Fidos
