defmodule Membrane.VideoInterop.SinkTest do
  use ExUnit.Case, async: true

  alias Membrane.Buffer
  alias Membrane.VideoInterop.Sink
  alias VideoInterop.{Format, Frame, Lease, Rect}
  alias VideoInterop.DMABuf
  alias VideoInterop.DMABuf.{Descriptor, FourCC, Layer, Object, Plane}

  test "submits a frame with the configured target and arguments" do
    frame = frame()
    opts = %Sink{submit: {__MODULE__, :submit, [self()]}, target: :preview}
    {[], state} = Sink.handle_init(nil, opts)

    assert {[], ^state} = Sink.handle_buffer(:input, %Buffer{payload: frame}, nil, state)
    assert_receive {:submitted, ^frame, :preview}
  end

  test "reports callback errors without releasing a consumed frame twice" do
    frame = frame()
    opts = %Sink{submit: {__MODULE__, :reject, [self()]}, target: :preview}
    {[], state} = Sink.handle_init(nil, opts)

    assert {[notify_parent: {:video_interop_sink_error, :rejected}], ^state} =
             Sink.handle_buffer(:input, %Buffer{payload: frame}, nil, state)

    assert_receive {:consumed_rejection, ^frame}
  end

  test "rejects invalid frames before invoking the callback" do
    frame = %{frame() | format: nil}
    opts = %Sink{submit: {__MODULE__, :submit, [self()]}, target: :preview}
    {[], state} = Sink.handle_init(nil, opts)

    assert {[notify_parent: {:video_interop_sink_error, {:invalid_frame, _reason}}], ^state} =
             Sink.handle_buffer(:input, %Buffer{payload: frame}, nil, state)

    refute_receive {:submitted, _frame, _target}
  end

  test "releases the frame when the callback raises" do
    frame = frame_with_lease(:raised)
    opts = %Sink{submit: {__MODULE__, :raise_submit, []}, target: :preview}
    {[], state} = Sink.handle_init(nil, opts)

    assert {[notify_parent: {:video_interop_sink_error, {:exception, %RuntimeError{}}}], ^state} =
             Sink.handle_buffer(:input, %Buffer{payload: frame}, nil, state)

    assert_receive {:video_interop_release, :raised, holder}
    assert holder == frame.lease.holder
  end

  def submit(frame, target, test_pid) do
    send(test_pid, {:submitted, frame, target})
    VideoInterop.release(frame)
  end

  def reject(frame, _target, test_pid) do
    send(test_pid, {:consumed_rejection, frame})
    VideoInterop.release(frame)
    {:error, :rejected}
  end

  def raise_submit(_frame, _target), do: raise("submit failed")

  defp frame do
    VideoInterop.Frame.binary(<<0, 0, 0, 255>>,
      width: 1,
      height: 1,
      pixel_format: :rgba8888
    )
  end

  defp frame_with_lease(token) do
    fourcc = FourCC.from_string!("AB24")

    %Frame{
      coded_width: 1,
      coded_height: 1,
      visible_rect: %Rect{x: 0, y: 0, width: 1, height: 1},
      format: %Format{
        width: 1,
        height: 1,
        framerate: nil,
        storage: %DMABuf.Format{fourcc: fourcc}
      },
      storage: %Descriptor{
        objects: [%Object{fd: 10, size: 4, modifier: :implicit}],
        layers: [
          %Layer{
            fourcc: fourcc,
            planes: [%Plane{object_index: 0, offset: 0, pitch: 4}]
          }
        ]
      },
      lease: Lease.new(self(), token)
    }
  end
end
