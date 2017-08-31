# Membrane.Element.Fade

This element applies fading curves to the data, performing fade in and fade out operations. 

# Usage
## Installation

Add the following line to your `deps` in `mix.exs`.  Run `mix deps.get`.

```elixir
{:membrane_element_fade, git: "git@github.com:membraneframework/membrane-element-fade.git"}
```

Then add the following line to your `applications` in `mix.exs`.

```elixir
:membrane_element_fade
```

## Fade.InOut
### Options
This module's options consist of:

#### initial level
This element performs all-time multiplication of the signal. `:initial_level` is an indication of how loud it should be at start. It can be specified as non-negative number in range between 0 and 1, with 0 being a muted signal, and 1 being 100% loudness. Technically this value can be greater than 1, however this element is not intended to serve as a gain.
#### fadings list
`:fadings_list` is, as its name specifies, a list. It contains maps, which specify fades parameters over time. They consist of following keys:
##### `:to_level`
This key specifies how loud should the signal be at the end of described fade. Requirements and further description are similar to those of `initial level`.
It is advised to never specify two neighbouring fades with the same levels.
Last specified fade's level will persist the element's loudness level until the program is stopped.
##### `:at_time`
When the fade should start, given in Membrane.Time units.
However, a fade will not start until the previous one has ended.
The fades should be specified in the same order as they are intended to be performed.
##### `:duration`
Time between start and finish of the fade, given in Membrane.Time units.
##### `:arg_range`
A fully optional (default 3.5) key that specifies +/- range of argument of tanh(x) function which is used for fading. If specified, it should be a positive number. Generally speaking, decreasing this keys' value without changing the `:duration` should give a feeling of more gentle slope, while increasing it should make fade function more steep in the middle of duration.

Correctly specified options could like like this:
```elixir
%InOut.Options{
  fadings_list: [
    %{to_level: 1, at_time: 0, duration: 2 |> Time.second, arg_range: 0.5},
    %{to_level: 0, at_time: 2 |> Time.second, duration: 3 |> Time.second},
    %{to_level: 0.5, at_time: 6 |> Time.second, duration: 3 |> Time.second},
    %{to_level: 1, at_time: 10 |> Time.second, duration: 3 |> Time.second, arg_range: 5},
    %{to_level: 0, at_time: 15 |> Time.second, duration: 10 |> Time.second}
  ],
  initial_level: 0}
```

# License

[LGPLv3](https://www.gnu.org/licenses/lgpl-3.0.en.html).


# Authors

* Jacek Fidos