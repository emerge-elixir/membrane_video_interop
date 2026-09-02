defmodule Membrane.VideoInterop.RawVideo do
  @moduledoc "Conversions between BEAM-owned VideoInterop frames and `Membrane.RawVideo`."

  alias Membrane.Buffer
  alias VideoInterop.{Binary, Format, Frame}
  alias VideoInterop.Binary.Plane

  @spec format_to_raw(Format.t()) :: {:ok, Membrane.RawVideo.t()} | {:error, term()}
  def format_to_raw(%Format{width: width, height: height, framerate: framerate, storage: storage}) do
    with {:ok, pixel_format} <- raw_pixel_format(storage) do
      {:ok,
       %Membrane.RawVideo{
         width: width,
         height: height,
         framerate: framerate,
         pixel_format: pixel_format,
         aligned: true
       }}
    end
  end

  def format_to_raw(format), do: {:error, {:unsupported_format, format}}

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
         {:ok, raw} <- format_to_raw(format),
         {:ok, row_bytes} <- row_bytes(raw.pixel_format, width),
         {:ok, payload} <- compact_rows(data, offset, stride, row_bytes, height) do
      {:ok, %Buffer{payload: payload}, raw}
    end
  end

  def frame_to_buffer(frame), do: {:error, {:unsupported_frame_storage, frame}}

  @spec frame_from_buffer(Buffer.t(), Membrane.RawVideo.t()) ::
          {:ok, Frame.t()} | {:error, term()}
  def frame_from_buffer(%Buffer{payload: payload}, %Membrane.RawVideo{} = raw)
      when is_binary(payload) do
    with {:ok, pixel_format} <- interop_pixel_format(raw.pixel_format),
         {:ok, row_bytes} <- row_bytes(raw.pixel_format, raw.width),
         true <- byte_size(payload) == row_bytes * raw.height do
      {:ok,
       Frame.binary(payload,
         width: raw.width,
         height: raw.height,
         pixel_format: pixel_format,
         framerate: raw.framerate,
         alpha_mode: interop_alpha_mode(pixel_format)
       )}
    else
      false -> {:error, {:invalid_payload_size, byte_size(payload)}}
      {:error, _reason} = error -> error
    end
  end

  def frame_from_buffer(buffer, format), do: {:error, {:unsupported_raw_video, buffer, format}}

  defp raw_pixel_format(%Binary.Format{pixel_format: :rgba8888}), do: {:ok, :RGBA}
  defp raw_pixel_format(%Binary.Format{pixel_format: :rgb888}), do: {:ok, :RGB}
  defp raw_pixel_format(storage), do: {:error, {:unsupported_raw_pixel_format, storage}}

  defp interop_pixel_format(:RGBA), do: {:ok, :rgba8888}
  defp interop_pixel_format(:RGB), do: {:ok, :rgb888}
  defp interop_pixel_format(format), do: {:error, {:unsupported_raw_pixel_format, format}}

  defp interop_alpha_mode(:rgba8888), do: :straight
  defp interop_alpha_mode(_pixel_format), do: :opaque

  defp row_bytes(:RGBA, width), do: {:ok, width * 4}
  defp row_bytes(:RGB, width), do: {:ok, width * 3}

  defp compact_rows(data, offset, stride, row_bytes, height)
       when stride >= row_bytes and offset >= 0 and height > 0 do
    required = offset + stride * (height - 1) + row_bytes

    if byte_size(data) >= required do
      payload =
        for row <- 0..(height - 1), into: <<>> do
          binary_part(data, offset + row * stride, row_bytes)
        end

      {:ok, payload}
    else
      {:error, {:binary_storage_too_small, byte_size(data), required}}
    end
  end
end
