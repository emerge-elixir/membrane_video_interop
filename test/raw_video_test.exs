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
        pixel_format: :rgba8888,
        alpha_mode: :straight
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

  test "converts tightly packed RGB frames in both directions" do
    frame =
      Frame.binary(<<1, 2, 3, 4, 5, 6>>,
        width: 2,
        height: 1,
        pixel_format: :rgb888
      )

    assert {:ok, %Buffer{payload: <<1, 2, 3, 4, 5, 6>>}, raw} =
             RawVideo.frame_to_buffer(frame)

    assert raw.pixel_format == :RGB

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

    assert {:error, {:invalid_payload_size, 1, 6}} =
             RawVideo.frame_from_buffer(
               %Buffer{payload: <<0>>},
               %{raw | pixel_format: :RGB}
             )
  end

  test "rejects RawVideo formats that cannot describe one complete frame" do
    raw = %Membrane.RawVideo{
      width: 1,
      height: 1,
      framerate: nil,
      pixel_format: :RGB,
      aligned: false
    }

    assert {:error, :unaligned_raw_video} =
             RawVideo.frame_from_buffer(%Buffer{payload: <<1, 2, 3>>}, raw)

    assert {:error, {:invalid_raw_video, _raw}} =
             RawVideo.frame_from_buffer(%Buffer{payload: <<>>}, %{raw | width: 0, aligned: true})

    assert {:error, {:invalid_framerate, {0, 1}}} =
             RawVideo.frame_from_buffer(
               %Buffer{payload: <<1, 2, 3>>},
               %{raw | aligned: true, framerate: {0, 1}}
             )
  end

  test "rejects cropped and premultiplied RGBA frames instead of losing their meaning" do
    frame =
      Frame.binary(<<255, 0, 0, 128>>,
        width: 1,
        height: 1,
        pixel_format: :rgba8888
      )

    assert {:error, {:unsupported_raw_pixel_format, _format}} =
             RawVideo.frame_to_buffer(frame)

    cropped =
      Frame.binary(<<255, 0, 0, 128, 0, 0, 0, 255>>,
        width: 2,
        height: 1,
        pixel_format: :rgba8888,
        alpha_mode: :straight
      )
      |> then(&%{&1 | visible_rect: %{&1.visible_rect | width: 1}})

    assert {:error, {:unsupported_visible_rect, _visible_rect}} =
             RawVideo.frame_to_buffer(cropped)
  end

  test "validates formats before constructing Membrane RawVideo values" do
    frame =
      Frame.binary(<<1, 2, 3>>,
        width: 1,
        height: 1,
        pixel_format: :rgb888
      )

    invalid = %{frame.format | width: 0}
    assert {:error, _reason} = RawVideo.format_to_raw(invalid)

    non_square = %{frame.format | pixel_aspect_ratio: {2, 1}}

    assert {:error, {:unsupported_format_metadata, ^non_square}} =
             RawVideo.format_to_raw(non_square)

    gray =
      Frame.binary(<<0>>,
        width: 1,
        height: 1,
        pixel_format: :gray8
      )

    assert {:error, {:unsupported_raw_pixel_format, _format}} =
             RawVideo.format_to_raw(gray.format)
  end

  test "rejects values outside the conversion API shapes" do
    assert {:error, {:unsupported_format, :not_a_format}} =
             RawVideo.format_to_raw(:not_a_format)

    assert {:error, {:unsupported_frame_storage, :not_a_frame}} =
             RawVideo.frame_to_buffer(:not_a_frame)

    buffer = %Buffer{payload: <<>>}

    assert {:error, {:unsupported_raw_video, ^buffer, :not_raw_video}} =
             RawVideo.frame_from_buffer(buffer, :not_raw_video)
  end
end
