# Membrane VideoInterop 0.1.0 Release Audit

Status: **local release candidate validated; publication infrastructure remains**

Audit date: 2026-09-03

## Decision

No source, ownership, compatibility, documentation, or package-closure defect
blocks version 0.1.0. The local release candidate passes the complete validation
matrix and resolves `video_interop 0.1.0` from Hex.

Do not create `v0.1.0` until the GitHub repository and protected Hex environment
exist. The declared repository URL currently returns HTTP 404, and this machine
has no GitHub or Hex publishing credentials.

## Release contract

The package provides the Membrane interface for VideoInterop frames:

- the source receives tagged `%VideoInterop.Frame{}` messages, follows Membrane
  demand, and retains at most one pending frame;
- the sink transfers each frame to an MFA callback under an explicit ownership
  contract;
- transport preserves owned binary and borrowed DMA-BUF storage;
- RawVideo conversion is restricted to complete, aligned, progressive RGB and
  straight-alpha RGBA frames in CPU-owned binaries.

The source default message tag is the framework-neutral
`:video_interop_frame`. Integrations with another producer protocol must set
`:message_tag` explicitly.

## Dependency and package state

`mix.exs` declares registry dependencies only:

```elixir
{:membrane_core, "~> 1.2"}
{:membrane_raw_video_format, "~> 0.4"}
{:video_interop, "~> 0.1.0"}
```

`mix.lock` resolves published `video_interop 0.1.0` with Hex checksum
`09d96389c29535a8fe6a994a3c12a3456119e6ede2f878b05711ea077f184deb`.
The package contains no path dependency, native code, build output, test source,
or maintainer-only plan.

The package contains 8 files and 30,403 unpacked bytes. The current archive is
15,360 bytes with SHA-256
`7d9fb2bf8ddb0ea06f9a4afe998c02a750af156d7afea34a858fb89ab7ed1516`.
Rebuild the archive from the exact tagged commit and verify the checksum before
approving publication.

## Validation results

The following gates pass:

- 22 tests on Elixir 1.20.2/OTP 29.0.5;
- 22 tests on Elixir 1.17.3/OTP 27.3.4.3;
- 22 tests with minimum dependencies `membrane_core 1.2.0` and
  `membrane_raw_video_format 0.4.0`;
- 97.8% built-in line coverage;
- formatting and warnings-as-errors compilation;
- ExDoc generation with warnings denied;
- Hex advisory audit and dependency currency check;
- GitHub Actions workflow lint;
- unpacked production package compilation from registry dependencies;
- exact version and dated changelog metadata for `v0.1.0`.

A fresh dependency compilation on Elixir 1.20 emits a deprecation warning from
transitive `qex 0.5.2`. Project compilation remains warning-free and the
warnings-as-errors gate passes.

## Publication blockers

1. Create `emerge-elixir/membrane_video_interop` on GitHub and make it public.
2. Push `main` to the configured `origin` and verify anonymous clone, README
   badges, package links, and Actions access.
3. Create a protected GitHub environment named `hex` with reviewer approval and
   a deployment tag rule matching `v*`.
4. Add a short-lived `HEX_API_KEY` environment secret with API write permission.
5. Confirm that `2026-09-03` is the publication date in `CHANGELOG.md`.
6. Run the full CI matrix on the pushed release commit.
7. Create and push annotated tag `v0.1.0` on that exact commit.
8. Review the successful tag gates and approve the protected `publish-hex`
   deployment.

The Hex API returns 404 for `membrane_video_interop`; version 0.1.0 is not
published.

## Post-publication verification

1. Fetch `{:membrane_video_interop, "== 0.1.0"}` in a clean Mix project.
2. Compile with warnings denied and run a minimal source-to-sink pipeline.
3. Verify HexDocs and source links against tag `v0.1.0`.
4. Create the GitHub release from the same tag.
5. Replace downstream path dependencies and regenerate locks only after the
   registry artifact passes verification.
