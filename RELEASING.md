# Releasing Membrane VideoInterop

`membrane_video_interop` is published to Hex only after its compatible
`video_interop` dependency is available and verified on Hex.

## Before tagging

1. Make <https://github.com/emerge-elixir/membrane_video_interop> public and
   verify anonymous clone and package links.
2. Confirm `video_interop 0.1.0` remains available from Hex.
3. Confirm `main` contains every release fix and matches the remote.
4. Create a short-lived Hex key at <https://hex.pm/dashboard/keys> with API
   write permission.
5. Store it only as the `HEX_API_KEY` environment secret in a protected GitHub
   environment named `hex`.
6. Require reviewer approval and restrict the environment to tags matching
   `v*`.
7. Confirm `CHANGELOG.md` contains the actual release date.
8. Start from a clean checkout.

Do not publish from a developer workstation. The protected `publish-hex` CI job
is the only publication path.

## Validate

Run with the supported current toolchain:

```sh
mix deps.get
mix format --check-formatted
mix compile --force --warnings-as-errors
mix test --warnings-as-errors
mix docs --warnings-as-errors
mix hex.audit
```

Repeat formatting, compilation, and tests with Elixir 1.17 and OTP 27. In a
temporary checkout, also test the minimum declared dependency versions:
`membrane_core 1.2.0` and `membrane_raw_video_format 0.4.0`.

Build and inspect the package:

```sh
mix hex.build --unpack --output /tmp/membrane_video_interop-0.1.0
```

The archive must contain only the intended Elixir source and user-facing
package files. It must not contain `_build`, `deps`, `doc`, native libraries,
credentials, or path dependencies.

Compile the unpacked package from registry dependencies:

```sh
(
  cd /tmp/membrane_video_interop-0.1.0
  MIX_ENV=prod mix deps.get
  MIX_ENV=prod mix compile --force --warnings-as-errors
)
```

Record the final commit, toolchains, package file list, archive checksum, and
test results in `plans/release-0.1.0-audit.md`.

## Tag and publish through CI

Create and push an annotated tag on the clean release commit:

```sh
git tag -a v0.1.0 -m "Release Membrane VideoInterop 0.1.0"
git push origin main
git push origin v0.1.0
```

The tag workflow runs the supported toolchain matrix, documentation and package
checks, and exact version/date validation. Only then does `publish-hex` wait for
approval on the protected `hex` environment.

Review the completed prerequisite jobs and approve the deployment. CI publishes
the package and documentation separately:

```sh
mix hex.publish package --yes
mix hex.publish docs --yes
```

Never move a public release tag. If publication fails before Hex accepts the
package, fix it in a new commit and release a new version.

## Verify the registry artifact

In a clean temporary Mix project, add:

```elixir
{:membrane_video_interop, "== 0.1.0"}
```

Run `mix deps.get`, compile with warnings denied, run a minimal source-to-sink
pipeline, and verify HexDocs source links point to `v0.1.0`. Then create the
GitHub release and migrate downstream applications from path dependencies.
