defmodule Membrane.VideoInterop.SourceTest do
  use ExUnit.Case, async: true

  alias Membrane.VideoInterop.Source
  alias VideoInterop.{Format, Frame, Lease, Rect}
  alias VideoInterop.DMABuf
  alias VideoInterop.DMABuf.{Descriptor, FourCC, Layer, Object, Plane}

  test "keeps only the latest pending frame and releases the replaced holder" do
    {[], state} = Source.handle_init(nil, %Source{notify: nil, message_tag: :frame})
    first = frame(:first)
    second = frame(:second)

    assert {[], state} = Source.handle_info({:frame, first}, nil, state)
    assert {[], state} = Source.handle_info({:frame, second}, nil, state)
    assert_receive {:video_interop_release, :first, first_holder}
    assert first_holder == first.lease.holder

    assert {[stream_format: {:output, format}, buffer: {:output, buffer}], state} =
             Source.handle_demand(:output, 1, :buffers, nil, state)

    assert format == second.format
    assert buffer.payload == second
    assert state.pending == nil
    assert state.demand == 0
    VideoInterop.release(buffer.payload)
    assert_receive {:video_interop_release, :second, second_holder}
    assert second_holder == second.lease.holder
  end

  test "releases pending ownership during termination" do
    {[], state} = Source.handle_init(nil, %Source{})
    pending = frame(:pending)
    {[], state} = Source.handle_info({:emerge_skia_frame, pending}, nil, state)

    assert {[terminate: :normal], %{pending: nil}} =
             Source.handle_terminate_request(nil, state)

    assert_receive {:video_interop_release, :pending, holder}
    assert holder == pending.lease.holder
  end

  test "releases invalid matching frames before admission" do
    {[], state} = Source.handle_init(nil, %Source{message_tag: :frame})
    invalid = %{frame(:invalid) | coded_width: 0}

    assert {[notify_parent: {:video_interop_source_error, _reason}], ^state} =
             Source.handle_info({:frame, invalid}, nil, state)

    assert_receive {:video_interop_release, :invalid, holder}
    assert holder == invalid.lease.holder
  end

  test "releases a demanded DMA-BUF frame that has no stream format" do
    {[], state} = Source.handle_init(nil, %Source{message_tag: :frame})
    {[], state} = Source.handle_demand(:output, 1, :buffers, nil, state)
    missing_format = %{frame(:missing_format) | format: nil}

    assert {[notify_parent: {:video_interop_source_error, :missing_frame_format}], ^state} =
             Source.handle_info({:frame, missing_format}, nil, state)

    assert_receive {:video_interop_release, :missing_format, holder}
    assert holder == missing_format.lease.holder
  end

  test "ignores messages outside the configured ingress contract" do
    {[], state} = Source.handle_init(nil, %Source{message_tag: :frame})
    assert {[], ^state} = Source.handle_info({:other, frame(:not_transferred)}, nil, state)
    refute_receive {:video_interop_release, :not_transferred, _holder}
  end

  test "notifies its configured producer when playback starts" do
    {[], state} = Source.handle_init(nil, %Source{notify: self()})
    assert {[], ^state} = Source.handle_playing(nil, state)
    assert_receive {:video_interop_source_ready, source}
    assert source == self()
  end

  defp frame(token) do
    format = %Format{
      width: 2,
      height: 2,
      framerate: {30, 1},
      storage: %DMABuf.Format{fourcc: FourCC.nv12()}
    }

    %Frame{
      coded_width: 2,
      coded_height: 2,
      visible_rect: %Rect{x: 0, y: 0, width: 2, height: 2},
      format: format,
      storage: %Descriptor{
        objects: [%Object{fd: 10, size: 6, modifier: :implicit}],
        layers: [
          %Layer{
            fourcc: FourCC.nv12(),
            planes: [
              %Plane{object_index: 0, offset: 0, pitch: 2},
              %Plane{object_index: 0, offset: 4, pitch: 2}
            ]
          }
        ]
      },
      lease: Lease.new(self(), token)
    }
  end
end
