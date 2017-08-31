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


  def handle_init(%Options{fade_in_duration: fade_in_duration, fade_in_start: fade_in_start, fade_out_start: fade_out_start, fade_out_duration: fade_out_duration}) do
    {:ok, %{
      fade_in_duration: fade_in_duration,
      fade_in_start: fade_in_start,
      fade_out_duration: fade_out_duration,
      fade_out_start: fade_out_start,
      sample_size: 0,
      leftover: <<>>,
      timeframe_byte_size: 0,
      arg_count: 0,
      current_arg: 0,
      current_fadein_sample: 1,
      fade_in_done: false,
      fade_in_duration_frames: 0,
      d_arg: 0.0,
      current_time: 0,
    }}
  end


  def handle_caps(:sink, %{format: format, channels: channels, sample_rate: sample_rate} = caps, _, %{fade_in_duration: fade_in_duration, fade_out_duration: fade_out_duration} = state) do
    {:ok, sample_size} = Raw.format_to_sample_size(format)
    tframes_in = get_required_timeframes_number(fade_in_duration, sample_rate)
    tframes_out = get_required_timeframes_number(fade_out_duration, sample_rate)
    {:ok, {
      [caps: {:source, caps}],
      %{state |
        fade_out_duration_frames: tframes_out,
        fade_in_duration_frames: tframes_in,
        sample_size: sample_size,
        timeframe_byte_size: channels * sample_size,
        arg_count: - div(tframes_in, 2) - 1,
        d_arg: get_d_arg(fade_in_duration, sample_rate, -3.5, 3.5),
        leftover: <<>>,
      }
    }}
  end


  def handle_demand(:source, size, :bytes, _, state) do
    {:ok, {[demand: {:sink, size}], state}}
  end


  def handle_process1(:sink, %Membrane.Buffer{payload: data}, %{caps: %Raw{} = caps}, %{leftover: leftover} = state) do
    {:ok, {faded_data, state}} = multiplicative_fader(leftover <> data, caps, state, <<>>)
    {:ok, {[buffer: {:source,  %Membrane.Buffer{payload: faded_data}}], state}}
  end


  defp multiplicative_fader(data, %Raw{channels: channels, sample_rate: sample_rate, format: format} = caps, 
                            %{current_time: current_time, fade_in_start: fade_in_start, d_arg: d_arg, arg_count: arg_count, timeframe_byte_size: timeframe_byte_size, sample_size: sample_size, fade_in_done: fade_in_done, fade_in_duration_frames: fade_in_duration_frames, fade_out_start: fade_out_start, fade_out_duration_frames: fade_out_duration_frames, fade_out_duration: fade_out_duration} = state, new_data) do
    case data do
      <<timeframe::binary-size(timeframe_byte_size), rest::binary>> ->
        state = %{state | current_time: current_time + (Time.seconds(1) / sample_rate)}
        if (fade_in_done == false) do
          if(current_time > fade_in_start) do
            new_data = new_data <> (timeframe |> multiply_channels_by_constant(tanh_normalized(arg_count * d_arg), format, sample_size) |> channels_list_to_binary(format))
            if (arg_count > div(fade_in_duration_frames, 2)) do
              multiplicative_fader(rest, caps, %{state | fade_in_done: true, d_arg: get_d_arg(fade_out_duration, sample_rate, -3.5, 3.5), arg_count: div(fade_out_duration_frames, 2)}, new_data)
            else
              multiplicative_fader(rest, caps, %{state | arg_count: arg_count + 1}, new_data)
            end
          else
            new_data = new_data <> (channels |> get_zeros_list |> channels_list_to_binary(format))
            multiplicative_fader(rest, caps, state, new_data)
          end
        else
          if(current_time > fade_out_start) do
            {new_data, state} = 
            if (arg_count < - div(fade_in_duration_frames, 2)) do
              {new_data <> (channels |> get_zeros_list |> channels_list_to_binary(format)), state}
            else
              {new_data <> (timeframe |> multiply_channels_by_constant(tanh_normalized(arg_count * d_arg), format, sample_size) |> channels_list_to_binary(format)), %{state | arg_count: arg_count - 1}}
            end
            multiplicative_fader(rest, caps, state, new_data)
          else
            {:ok, {new_data <> data, state}}
          end
        end
      leftover ->
        {:ok, {new_data, %{state | leftover: leftover, current_time: current_time + (Time.seconds(1) / sample_rate)}}}
    end
  end


  def e(), do: :math.exp(1) # base of the natural logarithm


  def get_d_arg(duration, sample_rate, low_arg, high_arg) do
    tframes = get_required_timeframes_number(duration, sample_rate)
    (high_arg-low_arg) / tframes
  end


  defp get_required_timeframes_number(period, sample_rate), do: (period * sample_rate) |> div(Time.second(1))


  defp tanh(x), do: (1 - :math.pow(e(), -2 * x)) / (1 + :math.pow(e(), -2 * x))

  defp tanh_normalized(x), do: (tanh(x) + 1) / 2 # y axis


  def get_zeros_list(len), do: for(_ <- 1..len, do: 0)


  def channels_list_to_binary(list, format), do: for(x <- list, into: "", do: Raw.value_to_sample!(x, format))


  def multiply_channels_by_constant(data, constant, format, sample_size), do: \
    for(<<x::binary-size(sample_size) <- data>>, do: round(Raw.sample_to_value!(x, format) * constant))
end