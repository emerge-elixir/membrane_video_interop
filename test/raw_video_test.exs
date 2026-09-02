defmodule Membrane.VideoInterop.RawVideoTest do
  use ExUnit.Case, async: true

  alias Membrane.Buffer
  alias Membrane.VideoInterop.RawVideo
  alias VideoInterop.{Binary, Frame}

  test "compacts padded RGBA rows without reading trailing stride padding" do
    frame =
      Frame.binary(<<1, 2, 3, 4, 99, 99, 5, 6, 7, 8>>,
        width: 1,
        height: 2,
        stride: 6,
        pixel_format: :rgba8888
      )

    # A packed last row need not contain padding that follows its visible bytes.
    frame = %{
      frame
      | storage: %Binary{frame.storage | data: binary_part(frame.storage.data, 0, 10)}
    }

    assert {:ok, %Buffer{payload: <<1, 2, 3, 4, 5, 6, 7, 8>>}, raw} =
             RawVideo.frame_to_buffer(frame)

    assert raw.pixel_format == :RGBA
    assert raw.width == 1
    assert raw.height == 2
  end

  test "converts RGB RawVideo buffers to owned VideoInterop frames" do
    raw = %Membrane.RawVideo{
      width: 2,
      height: 1,
      framerate: {25, 1},
      pixel_format: :RGB,
      aligned: true
    }

    assert {:ok, frame} = RawVideo.frame_from_buffer(%Buffer{payload: <<1, 2, 3, 4, 5, 6>>}, raw)
    assert :ok = VideoInterop.validate(frame)
    assert frame.storage.data == <<1, 2, 3, 4, 5, 6>>
    assert frame.format.storage.pixel_format == :rgb888
    assert frame.lease == nil
  end

  test "marks ordinary RGBA RawVideo payloads as straight alpha" do
    raw = %Membrane.RawVideo{
      width: 1,
      height: 1,
      framerate: nil,
      pixel_format: :RGBA,
      aligned: true
    }

    assert {:ok, frame} =
             RawVideo.frame_from_buffer(%Buffer{payload: <<255, 0, 0, 128>>}, raw)

    assert frame.format.alpha_mode == :straight
  end

  test "rejects unsupported pixel formats and invalid payload sizes" do
    raw = %Membrane.RawVideo{
      width: 2,
      height: 1,
      framerate: nil,
      pixel_format: :I420,
      aligned: true
    }

    assert {:error, {:unsupported_raw_pixel_format, :I420}} =
             RawVideo.frame_from_buffer(%Buffer{payload: <<0>>}, raw)

    assert {:error, {:invalid_payload_size, 1}} =
             RawVideo.frame_from_buffer(
               %Buffer{payload: <<0>>},
               %{raw | pixel_format: :RGB}
             )
  end
end
