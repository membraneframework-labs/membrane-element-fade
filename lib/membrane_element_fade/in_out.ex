defmodule Membrane.Element.Fade.InOut do
  use Membrane.Element.Base.Filter
  alias Membrane.Element.Fade.InOut.Options
  alias Membrane.Time
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw, as: Caps
  use Membrane.Mixins.Log, tags: __MODULE__
  use Membrane.Helper
  alias Membrane.Element.Fade.MultiplicativeFader, as: Fader

  def_known_source_pads %{
    :source => {:always, :pull, :any}
  }

  def_known_sink_pads %{
    :sink => {:always, {:pull, demand_in: :bytes}, :any}
  }


  def handle_init(%Options{
    fadings: fadings, initial_volume: initial_volume, step_time: step_time,
  }) do
    fadings = fadings |> Enum.sort_by(& &1.at_time)
    with :ok <- fadings |> validate_fadings do
      {:ok, %{
        time: 0,
        fadings: fadings,
        step_time: step_time,
        leftover: <<>>,
        static_volume: initial_volume,
        fader_state: nil,
      }}
    end
  end

  defp validate_fadings(fadings) do
    fadings
      |> Enum.chunk_every(2)
      |> Helper.Enum.each_with(fn
        [f1, f2] ->
          if f1.at_time + f1.duration <= f2.at_time do
            :ok
          else
            {:error, {:overlapping_fadings, f1, f2}}
          end
        _ -> :ok
      end)
  end


  def handle_caps(:sink, caps, _, state) do
    {{:ok, caps: {:source, caps}}, %{state | leftover: <<>>}}
  end


  def handle_demand(:source, size, :bytes, _, state) do
    {{:ok, demand: {:sink, size}}, state}
  end


  def handle_process1(:sink, %Buffer{payload: payload}, %{caps: caps}, state) do
    {payload, state} = state
      |> Map.get_and_update!(:leftover, & (&1 <> payload) |> Helper.Binary.int_rem(frame_size(caps)))
    {payload, state} = payload |> process_buffer(caps, state)
    {{:ok, buffer: {:source, %Buffer{payload: payload}}}, state}
  end

  defp process_buffer(<<>>, _caps, state) do
    {<<>>, state}
  end

  defp process_buffer(data, caps, %{fadings: [fading | fadings]} = state) do
    %{time: time, static_volume: static_volume, fader_state: fader_state} = state

    bytes_to_revolume = max(0, fading.at_time - time) |> time_to_bytes(caps)

    bytes_to_fade =
      (fading.duration - max(0, time - fading.at_time)) |> time_to_bytes(caps)

    {{to_revolume, to_fade, rest}, end_of_fading} =
      case data do
        <<to_revolume::binary-size(bytes_to_revolume), to_fade::binary-size(bytes_to_fade), rest::binary>>
          -> {{to_revolume, to_fade, rest}, true}
        <<to_revolume::binary-size(bytes_to_revolume), to_fade::binary>>
          -> {{to_revolume, to_fade, <<>>}, false}
        _
          -> {{data, <<>>, <<>>}, false}
      end

    revolumed = to_revolume |> Fader.revolume(caps, static_volume)
    step = (caps.sample_rate * state.step_time) |> div(1 |> Time.second) |> min(1)
    frames_left = bytes_to_fade |> div(frame_size caps)
    {faded, fader_state} = to_fade
      |> Fader.fade(frames_left, step, fading.to_level, fading.tanh_arg_range, static_volume, caps, fader_state)

    time = time + (((byte_size to_revolume) + (byte_size to_fade)) |> bytes_to_time(caps))

    state =
      if end_of_fading do
        %{state | fadings: fadings, time: time, static_volume: fading.to_level, fader_state: nil}
      else
        %{state | time: time, fader_state: fader_state}
      end

    {rest, state} = rest |> process_buffer(caps, state)
    {revolumed <> faded <> rest, state}
  end

  defp process_buffer(data, caps, %{fadings: []} = state) do
    data = data |> Fader.revolume(caps, state.static_volume)
    {data, state |> Map.update!(:time, & &1 + (data |> byte_size |> bytes_to_time(caps)))}
  end

  defp time_to_bytes(time, caps) when time >= 0 do
    ((time * caps.sample_rate / (1 |> Time.second)) |> :math.ceil |> trunc)
      * Caps.format_to_sample_size!(caps.format) * caps.channels
  end

  defp bytes_to_time(bytes, caps) when bytes >= 0 do
    bytes * (1 |> Time.second) / (caps.sample_rate * Caps.format_to_sample_size!(caps.format) * caps.channels)
  end

  # defp time_to_frames(time, caps) do
  #   (time * caps.sample_rate) |> div(1 |> Time.second)
  # end

  defp frame_size(caps) do
    Caps.format_to_sample_size!(caps.format) * caps.channels
  end

end
