defmodule Membrane.Element.Fade do
  alias Membrane.Buffer
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Time
  alias __MODULE__.Fading
  alias __MODULE__.MultiplicativeFader, as: Fader

  use Membrane.Element.Base.Filter
  use Membrane.Log, tags: :membrane_element_fade

  def_options fadings: [
                default: [],
                spec: [Fading.t()],
                description: """
                List containing `#{inspect(Fading)}` structs, which specify fade
                parameters over time. See the docs for `t:#{inspect(Fading)}.t/0` for details.
                """
              ],
              initial_volume: [
                default: 0,
                type: :number,
                spec: number,
                description: """
                The fader performs all-time multiplication of the signal.
                `:initial_volume` is an indication of how loud it should be at
                start. It can be specified as non-negative number, with 0 being
                a muted signal, and 1 being 100% loudness. Values greater than 1
                amplify the signal and may cause clipping.
                """
              ],
              step_time: [
                default: 5 |> Time.milliseconds(),
                type: :time,
                description: """
                Determines length of each chunk having equal volume level while
                fading.
                """
              ]

  def_output_pad :output, caps: Raw

  def_input_pad :input, demand_unit: :bytes, caps: Raw

  def handle_init(%__MODULE__{
        fadings: fadings,
        initial_volume: initial_volume,
        step_time: step_time
      }) do
    fadings = fadings |> Enum.sort_by(& &1.at_time)

    with :ok <- fadings |> validate_fadings do
      {:ok,
       %{
         time: 0,
         fadings: fadings,
         step_time: step_time,
         leftover: <<>>,
         static_volume: initial_volume,
         fader_state: nil
       }}
    end
  end

  defp validate_fadings(fadings) do
    fadings
    |> Enum.chunk_every(2, 1, :discard)
    |> Bunch.Enum.try_each(fn
      [%Fading{at_time: t1, duration: d}, %Fading{at_time: t2}] when t1 + d <= t2 ->
        :ok

      [f1, f2] ->
        {:error, {:overlapping_fadings, f1, f2}}
    end)
  end

  def handle_caps(:input, caps, _ctx, state) do
    {{:ok, caps: {:output, caps}}, %{state | leftover: <<>>}}
  end

  def handle_demand(:output, size, :bytes, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  def handle_process(:input, %Buffer{payload: payload}, ctx, state) do
    caps = ctx.pads.input.caps

    {payload, state} =
      state
      |> Map.get_and_update!(
        :leftover,
        &((&1 <> payload) |> Bunch.Binary.split_int_part(Raw.frame_size(caps)))
      )

    {payload, state} = payload |> process_buffer(caps, state)
    {{:ok, buffer: {:output, %Buffer{payload: payload}}}, state}
  end

  defp process_buffer(<<>>, _caps, state) do
    {<<>>, state}
  end

  defp process_buffer(data, caps, %{fadings: [fading | fadings]} = state) do
    %{time: time, static_volume: static_volume, fader_state: fader_state} = state

    bytes_to_revolume = max(0, fading.at_time - time) |> Raw.time_to_bytes(caps)

    bytes_to_fade = (fading.duration - max(0, time - fading.at_time)) |> Raw.time_to_bytes(caps)

    {{to_revolume, to_fade, rest}, end_of_fading} =
      case data do
        <<to_revolume::binary-size(bytes_to_revolume), to_fade::binary-size(bytes_to_fade),
          rest::binary>> ->
          {{to_revolume, to_fade, rest}, true}

        <<to_revolume::binary-size(bytes_to_revolume), to_fade::binary>> ->
          {{to_revolume, to_fade, <<>>}, false}

        _ ->
          {{data, <<>>, <<>>}, false}
      end

    revolumed = to_revolume |> Fader.revolume(caps, static_volume)
    step = (caps.sample_rate * state.step_time) |> div(1 |> Time.second()) |> min(1)
    frames_left = bytes_to_fade |> Raw.bytes_to_frames(caps)

    {faded, fader_state} =
      to_fade
      |> Fader.fade(
        frames_left,
        step,
        fading.to_level,
        fading.tanh_arg_range,
        static_volume,
        caps,
        fader_state
      )

    consumed_bytes = byte_size(to_revolume) + byte_size(to_fade)
    time = time + (consumed_bytes |> Raw.bytes_to_time(caps))

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
    {data, state |> Map.update!(:time, &(&1 + (data |> byte_size |> Raw.bytes_to_time(caps))))}
  end
end
