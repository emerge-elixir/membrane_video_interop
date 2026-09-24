# Changelog

## 0.1.1 - 2026-09-25

### Changed

- Require VideoInterop 0.1.2 or later in the 0.1 series to include its macOS
  portability fixes.

## 0.1.0 - 2026-09-03

First public release.

### Added

- Bounded latest-frame transport from producer messages into Membrane.
- Callback-based sinks with explicit frame ownership and release behavior.
- Conversion between aligned RGB or straight-alpha RGBA `Membrane.RawVideo`
  buffers and owned VideoInterop frames.
