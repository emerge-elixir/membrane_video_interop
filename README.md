# Membrane VideoInterop

Membrane elements for transporting `%VideoInterop.Frame{}` values without adding
Membrane dependencies to `video_interop` or Emerge dependencies here.

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
producer to send `{message_tag, frame}` directly to that PID. While downstream
has no demand, the source keeps only the latest frame and releases the frame it
replaces.

The sink invokes `module.function(frame, target, extra_args...)`. That callback
must consume the frame on every normal return. For Emerge:

```elixir
def submit_frame(frame, target) do
  Emerge.submit_video_frame(MyViewport, target, frame)
end
```

## Convert RawVideo

`Membrane.VideoInterop.RawVideo` converts binary RGB and RGBA frames to and from
`%Membrane.RawVideo{}` and `%Membrane.Buffer{}`. DMA-BUF frames stay in the
storage-neutral transport and are not copied through RawVideo conversion.

## Ownership

Owned binary frames have no lease. Borrowed DMA-BUF frames retain their exact
`VideoInterop.Lease`. The source releases invalid, replaced, and pending
shutdown frames. The sink releases a frame if its callback raises; otherwise
its callback owns consumption.

## License

Apache-2.0. See the [license](https://github.com/emerge-elixir/membrane_video_interop/blob/v0.1.0/LICENSE).
