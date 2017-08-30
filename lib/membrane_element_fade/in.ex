defmodule Membrane.Element.Fade.In do
  alias Membrane.Element.Fade.In.Options
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


  def handle_init(%Options{fade_duration: fade_duration, countdown: countdown}) do
    {:ok, %{
      fade_duration: fade_duration,
      countdown: countdown,
      sample_size: 0,
      timeframe_byte_size: 0
    }}
  end


  def handle_caps(:sink, %{format: format, channels: channels, sample_rate: sample_rate} = caps, _, %{fade_duration: fade_duration} = state) do
    {:ok, sample_size} = Raw.format_to_sample_size(format)

    {:ok, {
      [caps: {:source, caps}],
      %{state |
        sample_size: sample_size,
        timeframe_byte_size: channels * sample_size,
        slope: generate_slope(fade_duration, sample_rate),
        leftover: <<>>
      }
    }}
  end


  def handle_demand(:source, size, _, state) do
    {:ok, {[demand: {:sink, size}], state}}
  end


  def handle_process1(:sink, %Membrane.Buffer{payload: data}, %{caps: %Raw{} = caps}, %{leftover: leftover} = state) do
    {:ok, {faded_data, state}} = multiplicative_fader(leftover <> data, caps, state, <<>>)
    {:ok, {[buffer: {:source,  %Membrane.Buffer{payload: faded_data}}], state}}
  end


  defp multiplicative_fader(data, %Raw{} = _caps, %{slope: slope} = state, new_data) when slope==[] do
    {:ok, {new_data <> data, state}}
  end


  defp multiplicative_fader(data, %Raw{channels: channels, sample_rate: sample_rate, format: format} = caps, %{countdown: countdown, slope: [slope_hd, slope_tl], timeframe_byte_size: timeframe_byte_size, sample_size: sample_size} = state, new_data) do
    case data do
      <<timeframe::binary-size(timeframe_byte_size), rest::binary>> ->
        if(countdown <= 0) do
          new_data = new_data <> (timeframe |> multiply_channels_by_constant(slope_hd, format, sample_size) |> round |> channels_list_to_binary(format))
          multiplicative_fader(rest, caps, %{state | slope: slope_tl}, new_data)
        else
          new_data = new_data <> (channels |> get_zeros_list |> channels_list_to_binary(format))
          multiplicative_fader(rest, caps, %{state | countdown: countdown - (Time.seconds(1) / sample_rate)}, new_data)
        end
      leftover ->
        {:ok, {new_data, %{state | leftover: leftover}}}
    end
  end


  def e(), do: :math.exp(1) # base of the natural logarithm


  def generate_slope(duration, sample_rate) do
    tframes = get_required_timeframes_number(duration, sample_rate)
    for x <- normalized_range(tframes, -3.5, 3.5), do: tanh_normalized(x)
  end


  defp get_required_timeframes_number(period, sample_rate), do: (period * sample_rate) |> div(Time.second(1))


  defp tanh(x), do: (1 - :math.pow(e(), -2 * x)) / (1 + :math.pow(e(), -2 * x))

  defp tanh_normalized(x), do: (tanh(x) + 1) / 2 # y axis


  defp normalized_range(elems_number, low_boundary, high_boundary) do # x axis
    Enum.map(1..elems_number, &((high_boundary - low_boundary) * (&1 - 1) / (elems_number - 1) + low_boundary))
  end


  def get_zeros_list(len), do: for(_ <- 1..len, do: 0)


  def channels_list_to_binary(list, format), do: for(x <- list, into: "", do: Raw.value_to_sample!(x, format))

  def multiply_channels_by_constant(data, constant, format, sample_size), do: \
    for(<<x::binary-size(sample_size) <- data>>, do: Raw.sample_to_value!(x, format) * constant)
end