# Membrane VideoInterop

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_interop.svg)](https://hex.pm/packages/membrane_video_interop)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/membrane_video_interop)
[![CI](https://github.com/emerge-elixir/membrane_video_interop/actions/workflows/ci.yml/badge.svg)](https://github.com/emerge-elixir/membrane_video_interop/actions/workflows/ci.yml)

Membrane source and sink elements for transporting `%VideoInterop.Frame{}`
values, with helpers for converting owned RGB and RGBA frames to and from
`Membrane.RawVideo`.

Version 0.1 supports Elixir 1.17/OTP 27 and later.

## Installation

```elixir
def deps do
  [
    {:membrane_video_interop, "~> 0.1.0"}
  ]
end
```

## Transport frames

```elixir
child(:frames, %Membrane.VideoInterop.Source{notify: self()})
|> child(:display, %Membrane.VideoInterop.Sink{
  submit: {MyApp, :submit_frame, []},
  target: :camera
})
```

The source reports `{:video_interop_source_ready, pid}` to `notify`. Configure a
producer to send `{message_tag, frame}` directly to that PID. Sending a matching
message transfers ownership to the source; the producer must not release it
afterward. While downstream has no demand, the source keeps only the latest
frame and releases the frame it replaces. Invalid matching frames notify the
pipeline parent with `{:video_interop_source_error, reason}`.

The sink invokes `module.function(frame, target, extra_args...)`. That callback
must consume the frame on every normal return. Invalid payloads and callback
failures notify the pipeline parent with `{:video_interop_sink_error, reason}`.

## Convert RawVideo

`Membrane.VideoInterop.RawVideo` converts tightly framed RGB and straight-alpha
RGBA frames to and from `%Membrane.RawVideo{}` and `%Membrane.Buffer{}`. The
conversion requires aligned progressive frames, square pixels, and a full
visible rectangle. `Membrane.RawVideo` does not carry VideoInterop colorimetry.
DMA-BUF frames stay in the storage-neutral transport and are not copied through
RawVideo conversion.

## Ownership

Owned binary frames have no lease. Borrowed DMA-BUF frames retain their exact
`VideoInterop.Lease`. The source releases invalid, replaced, and pending
shutdown frames. The sink releases a frame if its callback raises, exits, or
throws. Every normal callback return consumes the frame, even when it reports
an error; a callback must not transfer ownership and then raise.

See the [changelog](CHANGELOG.md) for release notes.

## License

Apache-2.0. See the
[license](https://github.com/emerge-elixir/membrane_video_interop/blob/v0.1.0/LICENSE).
