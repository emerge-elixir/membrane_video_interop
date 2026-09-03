# Membrane VideoInterop

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_interop.svg)](https://hex.pm/packages/membrane_video_interop)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/membrane_video_interop)
[![CI](https://github.com/emerge-elixir/membrane_video_interop/actions/workflows/ci.yml/badge.svg)](https://github.com/emerge-elixir/membrane_video_interop/actions/workflows/ci.yml)

## The problem

[Membrane](https://membrane.stream/) is a multimedia framework. Its official
elements exchange CPU-owned binary payloads in `%Membrane.Buffer{}` structs.
Converting a GPU-bound frame into a CPU-owned binary copies the frame out of GPU
storage and breaks a zero-copy pipeline.

A zero-copy GPU pipeline passes DMA-BUF descriptors between its elements. Each
frame also carries synchronization state and an ownership contract so that its
DMA-BUF remains valid until the consumer finishes using it. Rust elements
produce and consume the GPU frames while the Membrane pipeline runs in Elixir.

[VideoInterop](https://hex.pm/packages/video_interop) defines the frame, DMA-BUF,
synchronization, lease, and ownership primitives for that Rust and Elixir
boundary. VideoInterop is framework-neutral and does not define Membrane
elements.

## The solution

Membrane VideoInterop builds on VideoInterop and exposes
`%VideoInterop.Frame{}` through Membrane source and sink elements. Together, the
two libraries provide the transport and ownership model for zero-copy GPU
Membrane pipelines defined in Elixir with elements written in Rust.

The transport preserves the frame's storage representation:

- `Membrane.VideoInterop.Source` accepts tagged frame messages, follows
  downstream demand, and retains at most one pending frame.
- `Membrane.VideoInterop.Sink` hands each frame to a configured callback with an
  explicit consumption contract.
- `Membrane.VideoInterop.RawVideo` performs explicit conversion between
  compatible CPU-owned RGB or RGBA frames and raw-video buffers.

The transport elements place the frame directly in
`%Membrane.Buffer{payload: frame}`. DMA-BUF descriptors, synchronization
metadata, and leases remain attached to the frame.

## Installation

```elixir
def deps do
  [
    {:membrane_video_interop, "~> 0.1.0"}
  ]
end
```

Version 0.1 supports Elixir 1.17/OTP 27 and later.

## Transport frames

Add the source and sink to a pipeline:

```elixir
child(:frames, %Membrane.VideoInterop.Source{
  notify: producer_pid,
  message_tag: :video_frame
})
|> child(:display, %Membrane.VideoInterop.Sink{
  submit: {MyFrameConsumer, :submit, []},
  target: :camera
})
```

When playback starts, the source sends
`{:video_interop_source_ready, source_pid}` to `producer_pid`. The producer then
transfers a frame to the source:

```elixir
send(source_pid, {:video_frame, frame})
```

The sink invokes the configured callback as
`MyFrameConsumer.submit(frame, :camera)`. Extra values in the MFA tuple are
appended after the target.

Invalid source frames and sink failures are reported to the pipeline parent as
`{:video_interop_source_error, reason}` and
`{:video_interop_sink_error, reason}` respectively.

## Ownership rules

- Sending a matching `{message_tag, frame}` transfers ownership to the source.
  The producer must not release or reuse that frame afterward.
- Messages with another tag are ignored and do not transfer ownership.
- The source releases invalid frames, replaced pending frames, and pending
  frames during shutdown.
- Once the sink callback is entered, the callback must consume the frame on
  every normal return, including error returns.
- The sink releases the frame when validation fails or the callback raises,
  exits, or throws. A callback must not transfer ownership and then raise.

Owned binary frames have no lease. Borrowed DMA-BUF frames retain their exact
`VideoInterop.Lease` throughout transport.

## Convert RawVideo

For compatible owned frames, conversion is explicit:

```elixir
alias Membrane.VideoInterop.RawVideo

{:ok, buffer, raw_format} = RawVideo.frame_to_buffer(frame)
{:ok, frame} = RawVideo.frame_from_buffer(buffer, raw_format)
```

Conversion supports aligned, progressive RGB and straight-alpha RGBA frames
with square pixels and a full visible rectangle. `Membrane.RawVideo` does not
carry VideoInterop colorimetry. DMA-BUF frames are not copied by these helpers.

See the [changelog](CHANGELOG.md) for release notes.

## License

Apache-2.0. See the
[license](https://github.com/emerge-elixir/membrane_video_interop/blob/v0.1.0/LICENSE).
