defmodule Membrane.VideoInterop.Sink do
  @moduledoc """
  Consumes `%VideoInterop.Frame{}` buffers through a configured callback.

  The callback is invoked as `module.function(frame, target, extra_args...)` and
  must consume the frame on every normal return. This keeps the package
  independent of Emerge while allowing `Emerge.submit_video_frame/3` adapters.
  """

  use Membrane.Sink

  alias Membrane.Buffer
  alias VideoInterop.Frame

  def_input_pad(:input,
    accepted_format: VideoInterop.Format,
    flow_control: :auto
  )

  def_options(
    submit: [
      spec: {module(), atom(), [term()]},
      description: "MFA invoked for each frame"
    ],
    target: [
      spec: term(),
      description: "Target passed as the callback's second argument"
    ]
  )

  @impl true
  def handle_init(_ctx, opts), do: {[], %{submit: opts.submit, target: opts.target}}

  @impl true
  def handle_buffer(:input, %Buffer{payload: %Frame{} = frame}, _ctx, state) do
    case VideoInterop.validate(frame) do
      :ok ->
        submit(frame, state)

      {:error, reason} ->
        VideoInterop.release(frame)
        {[notify_parent: {:video_interop_sink_error, {:invalid_frame, reason}}], state}
    end
  end

  def handle_buffer(:input, %Buffer{payload: payload}, _ctx, state) do
    {[notify_parent: {:video_interop_sink_error, {:invalid_payload, payload}}], state}
  end

  defp submit(frame, state) do
    case invoke(state.submit, frame, state.target) do
      :ok ->
        {[], state}

      {:error, reason} ->
        {[notify_parent: {:video_interop_sink_error, reason}], state}

      other ->
        {[notify_parent: {:video_interop_sink_error, {:invalid_submit_result, other}}], state}
    end
  rescue
    error ->
      VideoInterop.release(frame)
      {[notify_parent: {:video_interop_sink_error, {:exception, error}}], state}
  catch
    kind, reason ->
      VideoInterop.release(frame)
      {[notify_parent: {:video_interop_sink_error, {kind, reason}}], state}
  end

  defp invoke({module, function, extra_args}, frame, target) do
    apply(module, function, [frame, target | extra_args])
  end
end
