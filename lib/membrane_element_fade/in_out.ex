defmodule Membrane.Element.Fade.InOut do
  alias Membrane.Element.Fade.InOut.Options
  alias Membrane.Time
  alias Membrane.Caps.Audio.Raw
  use Membrane.Element.Base.Filter
  use Membrane.Mixins.Log
  alias Membrane.Time

  def_known_source_pads %{
    :source => {:always, :pull, :any}
  }

  def_known_sink_pads %{
    :sink => {:always, {:pull, demand_in: :bytes}, :any}
  }


  def handle_init(%Options{fadings: fadings, initial_volume: initial_volume}) do
    {:ok, %{
      arg_range: 3,
      current_arg: 0,
      current_time: 0,
      current_fade_duration_samples: 0,
      d_arg: 0.0,
      fadings: fadings,
      fade_in_progress: false,
      leftover: <<>>,
      sample_duration: 0.0,
      sample_size: 0,
      current_static_volume: initial_volume,
      tanh_range: 1,
      timeframe_byte_size: 0,
    }}
  end


  def handle_caps(:sink, %{format: format, channels: channels, sample_rate: sample_rate} = caps, _, state) do
    {:ok, sample_size} = Raw.format_to_sample_size(format)
    {{:ok, caps: {:source, caps}},
      %{state |
        sample_size: sample_size,
        sample_duration: (Time.seconds(1) / sample_rate),
        timeframe_byte_size: channels * sample_size,
        leftover: <<>>,
      }
    }
  end


  def handle_demand(:source, size, :bytes, _, state) do
    {{:ok, demand: {:sink, size}}, state}
  end


  def handle_process1(:sink, %Membrane.Buffer{payload: data}, %{caps: %Raw{} = caps}, %{leftover: leftover} = state) do
    {:ok, {faded_data, state}} = multiplicative_fader(leftover <> data, caps, state, <<>>)
    {{:ok, buffer: {:source,  %Membrane.Buffer{payload: faded_data}}}, state}
  end


  defp multiplicative_fader(data, %Raw{format: format} = _caps, %{fadings: [], current_static_volume: current_static_volume, sample_size: sample_size} = state, new_data) do
    {:ok, {new_data <> (data |> set_channels_volume(current_static_volume, format, sample_size)), state}}
  end

  defp multiplicative_fader(data, %Raw{format: format, sample_rate: sample_rate} = caps,
                            %{arg_range: arg_range, sample_size: sample_size, current_static_volume: current_static_volume, current_time: current_time, sample_duration: sample_duration, d_arg: d_arg, tanh_range: tanh_range,
                            timeframe_byte_size: timeframe_byte_size, fade_in_progress: fade_in_progress, fadings: [fadings_hd | fadings_tl], current_fade_duration_samples: current_fade_duration_samples, current_arg: current_arg} = state,
                            new_data) do

    case data do
      <<timeframe::binary-size(timeframe_byte_size), rest::binary>> ->
        if(fade_in_progress == false) do
          if(fadings_hd.at_time <= current_time * sample_duration) do
            current_fade_duration_samples = get_required_timeframes_number(fadings_hd.duration, sample_rate)
            multiplicative_fader(
              data,
              caps,
              %{
                state | fade_in_progress: true,
                arg_range: fadings_hd.tanh_arg_range,
                current_fade_duration_samples: current_fade_duration_samples,
                d_arg: get_d_arg(current_fade_duration_samples, -fadings_hd.tanh_arg_range, fadings_hd.tanh_arg_range),
                current_arg: 0,
                tanh_range: tanh(fadings_hd.tanh_arg_range),
              },
              new_data
            )
          else
            multiplicative_fader(
              rest,
              caps,
              %{state | current_time: current_time + 1},
              new_data <> (timeframe |> set_channels_volume(current_static_volume, format, sample_size))
            )
          end

        else
          if(current_arg > current_fade_duration_samples) do
            multiplicative_fader(data, caps, %{state | fade_in_progress: false, current_static_volume: fadings_hd.to_level, fadings: fadings_tl}, new_data)
          else
            fading_factor = tanh_normalized(current_arg * d_arg - arg_range, tanh_range, current_static_volume, fadings_hd.to_level)
            multiplicative_fader(
              rest,
              caps,
              %{state | current_time: current_time + 1, current_arg: current_arg + 1},
              new_data <> (timeframe |> set_channels_volume(fading_factor, format, sample_size))
            )
          end
        end

      leftover ->
        {:ok, {new_data, %{state | leftover: leftover}}}
    end
  end

  defp get_volume_level(x), do: (:math.exp(x)-1)/(e()-1)

  def e(), do: :math.exp(1) # base of the natural logarithm


  def get_d_arg(tframes, low_arg, high_arg), do: (high_arg-low_arg) / tframes


  defp get_required_timeframes_number(period, sample_rate), do: (period * sample_rate) |> div(Time.second(1))


  defp tanh(x), do: (1 - :math.pow(e(), -2 * x)) / (1 + :math.pow(e(), -2 * x))

  def tanh_normalized(x, range, old, new), do: ((tanh(x) + range)/(2*range)) *(new-old) + old # y axis


  def get_zeros_list(len), do: for(_ <- 1..len, do: 0)


  def set_channels_volume(data, 1, _format, _sample_size), do: data
  def set_channels_volume(data, volume, format, sample_size) do
    volume_level = get_volume_level(volume)
    for <<x::binary-size(sample_size) <- data>>, into: <<>>, do:
      x
        |> Raw.sample_to_value!(format)
        |> Kernel.*(volume_level)
        |> round
        |> Raw.value_to_sample!(format)
  end

end
