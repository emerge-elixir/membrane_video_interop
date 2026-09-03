defmodule Membrane.VideoInterop.RawVideo do
  @moduledoc """
  Converts tightly framed RGB and straight-alpha RGBA video between VideoInterop
  and `Membrane.RawVideo`.

  `Membrane.RawVideo` cannot represent visible cropping, pixel aspect ratio,
  interlacing, alpha interpretation, or colorimetry. Conversion therefore
  requires a full visible frame, square pixels, progressive scan, and straight
  alpha for RGBA. Colorimetry is not carried by `Membrane.RawVideo`.
  """

  alias Membrane.Buffer
  alias VideoInterop.{Binary, Format, Frame, Rect}
  alias VideoInterop.Binary.Plane

  @spec format_to_raw(Format.t()) :: {:ok, Membrane.RawVideo.t()} | {:error, term()}
  def format_to_raw(%Format{} = format) do
    with :ok <- VideoInterop.validate(format),
         :ok <- validate_representable_format(format),
         {:ok, pixel_format} <- raw_pixel_format(format) do
      {:ok,
       %Membrane.RawVideo{
         width: format.width,
         height: format.height,
         framerate: format.framerate,
         pixel_format: pixel_format,
         aligned: true
       }}
    end
  end

  def format_to_raw(format), do: {:error, {:unsupported_format, format}}

  @doc """
  Copies one owned binary frame into a tightly packed Membrane buffer.

  The input must describe a full, progressive RGB or straight-alpha RGBA frame.
  DMA-BUF storage and cropped frames are not copied by this helper.
  """
  @spec frame_to_buffer(Frame.t()) ::
          {:ok, Buffer.t(), Membrane.RawVideo.t()} | {:error, term()}
  def frame_to_buffer(
        %Frame{
          coded_width: width,
          coded_height: height,
          format: %Format{} = format,
          storage: %Binary{data: data, planes: [%Plane{offset: offset, stride: stride}]}
        } = frame
      ) do
    with :ok <- VideoInterop.validate(frame),
         :ok <- validate_full_visible_rect(frame),
         {:ok, raw} <- format_to_raw(format),
         {:ok, row_bytes} <- row_bytes(raw.pixel_format, width),
         {:ok, payload} <- compact_rows(data, offset, stride, row_bytes, height) do
      {:ok, %Buffer{payload: payload}, raw}
    end
  end

  def frame_to_buffer(frame), do: {:error, {:unsupported_frame_storage, frame}}

  @doc """
  Converts one aligned, tightly packed RGB or RGBA Membrane buffer into an owned
  VideoInterop frame.

  RGBA payloads are interpreted as straight alpha. Buffer timestamps and
  metadata remain transport concerns and are not copied into the frame.
  """
  @spec frame_from_buffer(Buffer.t(), Membrane.RawVideo.t()) ::
          {:ok, Frame.t()} | {:error, term()}
  def frame_from_buffer(%Buffer{payload: payload}, %Membrane.RawVideo{} = raw)
      when is_binary(payload) do
    with :ok <- validate_raw_format(raw),
         {:ok, pixel_format} <- interop_pixel_format(raw.pixel_format),
         {:ok, expected_size} <- Membrane.RawVideo.frame_size(raw),
         :ok <- validate_payload_size(payload, expected_size) do
      {:ok,
       Frame.binary(payload,
         width: raw.width,
         height: raw.height,
         pixel_format: pixel_format,
         framerate: raw.framerate,
         alpha_mode: interop_alpha_mode(pixel_format)
       )}
    end
  end

  def frame_from_buffer(buffer, format), do: {:error, {:unsupported_raw_video, buffer, format}}

  defp validate_representable_format(%Format{
         pixel_aspect_ratio: {1, 1},
         interlace_mode: :progressive
       }),
       do: :ok

  defp validate_representable_format(format),
    do: {:error, {:unsupported_format_metadata, format}}

  defp validate_full_visible_rect(%Frame{
         coded_width: width,
         coded_height: height,
         visible_rect: %Rect{x: 0, y: 0, width: width, height: height}
       }),
       do: :ok

  defp validate_full_visible_rect(%Frame{visible_rect: visible_rect}),
    do: {:error, {:unsupported_visible_rect, visible_rect}}

  defp validate_raw_format(%Membrane.RawVideo{
         width: width,
         height: height,
         framerate: framerate,
         aligned: true
       })
       when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    validate_framerate(framerate)
  end

  defp validate_raw_format(%Membrane.RawVideo{aligned: false}),
    do: {:error, :unaligned_raw_video}

  defp validate_raw_format(raw), do: {:error, {:invalid_raw_video, raw}}

  defp validate_framerate(nil), do: :ok

  defp validate_framerate({numerator, denominator})
       when is_integer(numerator) and numerator > 0 and is_integer(denominator) and
              denominator > 0,
       do: :ok

  defp validate_framerate(framerate), do: {:error, {:invalid_framerate, framerate}}

  defp raw_pixel_format(%Format{
         storage: %Binary.Format{pixel_format: :rgba8888},
         alpha_mode: :straight
       }),
       do: {:ok, :RGBA}

  defp raw_pixel_format(%Format{
         storage: %Binary.Format{pixel_format: :rgb888},
         alpha_mode: :opaque
       }),
       do: {:ok, :RGB}

  defp raw_pixel_format(format), do: {:error, {:unsupported_raw_pixel_format, format}}

  defp interop_pixel_format(:RGBA), do: {:ok, :rgba8888}
  defp interop_pixel_format(:RGB), do: {:ok, :rgb888}
  defp interop_pixel_format(format), do: {:error, {:unsupported_raw_pixel_format, format}}

  defp interop_alpha_mode(:rgba8888), do: :straight
  defp interop_alpha_mode(_pixel_format), do: :opaque

  defp row_bytes(:RGBA, width), do: {:ok, width * 4}
  defp row_bytes(:RGB, width), do: {:ok, width * 3}

  defp validate_payload_size(payload, expected_size) do
    case byte_size(payload) do
      ^expected_size -> :ok
      actual_size -> {:error, {:invalid_payload_size, actual_size, expected_size}}
    end
  end

  defp compact_rows(data, offset, row_bytes, row_bytes, height)
       when offset >= 0 and height > 0 do
    {:ok, binary_part(data, offset, row_bytes * height)}
  end

  defp compact_rows(data, offset, stride, row_bytes, height)
       when stride > row_bytes and offset >= 0 and height > 0 do
    payload =
      0..(height - 1)
      |> Enum.map(&binary_part(data, offset + &1 * stride, row_bytes))
      |> IO.iodata_to_binary()

    {:ok, payload}
  end
end
