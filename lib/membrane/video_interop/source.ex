defmodule Membrane.VideoInterop.Source do
  @moduledoc """
  Receives `%VideoInterop.Frame{}` messages and exposes them on a Membrane pad.

  The element is a bounded latest-frame ingress. When downstream has no demand,
  a new frame replaces and releases the previously pending frame.
  """

  use Membrane.Source

  alias Membrane.Buffer
  alias VideoInterop.Frame

  def_output_pad(:output,
    accepted_format: VideoInterop.Format,
    flow_control: :manual,
    demand_unit: :buffers
  )

  def_options(
    notify: [
      spec: pid() | nil,
      default: nil,
      description: "Process notified with the source element PID when playback starts"
    ],
    message_tag: [
      spec: atom() | String.t(),
      default: :emerge_skia_frame,
      description: "Tag expected in `{tag, frame}` ingress messages"
    ]
  )

  @impl true
  def handle_init(_ctx, opts) do
    {[],
     %{notify: opts.notify, message_tag: opts.message_tag, demand: 0, pending: nil, format: nil}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    if state.notify, do: send(state.notify, {:video_interop_source_ready, self()})
    {[], state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    emit_pending(%{state | demand: state.demand + size})
  end

  @impl true
  def handle_info({tag, %Frame{} = frame}, _ctx, %{message_tag: tag} = state) do
    case VideoInterop.validate(frame) do
      :ok ->
        admit(frame, state)

      {:error, reason} ->
        VideoInterop.release(frame)
        {[notify_parent: {:video_interop_source_error, reason}], state}
    end
  end

  def handle_info(_message, _ctx, state), do: {[], state}

  @impl true
  def handle_terminate_request(_ctx, state) do
    release_pending(state.pending)
    {[terminate: :normal], %{state | pending: nil}}
  end

  defp admit(frame, %{demand: demand} = state) when demand > 0 do
    output(frame, state)
  end

  defp admit(frame, state) do
    release_pending(state.pending)
    {[], %{state | pending: frame}}
  end

  defp emit_pending(%{demand: demand, pending: %Frame{} = frame} = state) when demand > 0 do
    output(frame, %{state | pending: nil})
  end

  defp emit_pending(state), do: {[], state}

  defp output(%Frame{format: %VideoInterop.Format{} = format} = frame, state) do
    format_action = if state.format == format, do: [], else: [stream_format: {:output, format}]
    actions = format_action ++ [buffer: {:output, %Buffer{payload: frame}}]
    {actions, %{state | demand: state.demand - 1, format: format}}
  end

  defp output(frame, state) do
    VideoInterop.release(frame)
    {[notify_parent: {:video_interop_source_error, :missing_frame_format}], state}
  end

  defp release_pending(nil), do: :ok
  defp release_pending(frame), do: VideoInterop.release(frame)
end
