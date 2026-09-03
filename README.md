# Membrane VideoInterop

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_interop.svg)](https://hex.pm/packages/membrane_video_interop)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/membrane_video_interop)
[![CI](https://github.com/emerge-elixir/membrane_video_interop/actions/workflows/ci.yml/badge.svg)](https://github.com/emerge-elixir/membrane_video_interop/actions/workflows/ci.yml)

## The problem

Membrane pipelines are demand-driven, while video producers and consumers often
exchange `%VideoInterop.Frame{}` values asynchronously. Those frames may contain
ordinary immutable binaries or borrowed DMA-BUF storage with synchronization
metadata and a lease.

Application-specific bridges must preserve that storage contract, avoid
retaining stale frames when demand stops, and release every borrowed frame on
replacement, rejection, failure, and shutdown. Converting every frame to
`Membrane.RawVideo` is not a general solution: GPU-backed frames would require a
CPU copy and lose their original storage metadata.

## The solution

Membrane VideoInterop carries complete `%VideoInterop.Frame{}` values through a
pipeline without changing their storage representation:

- `Membrane.VideoInterop.Source` accepts tagged frame messages, follows
  downstream demand, and retains at most one pending frame.
- `Membrane.VideoInterop.Sink` hands each frame to a configured callback with an
  explicit consumption contract.
- `Membrane.VideoInterop.RawVideo` converts compatible owned RGB and RGBA frames
  when a regular raw-video buffer is actually needed.

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
`{:video_interop_source_ready, source_pid}` to `producer_pid`. The producer can
then transfer a frame to the source:

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
