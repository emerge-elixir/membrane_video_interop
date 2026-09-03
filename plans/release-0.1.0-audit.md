# Membrane VideoInterop 0.1.0 Release Audit

Status: **implementation candidate prepared; external release setup remains**

Audit date: 2026-09-03

Candidate state: local working tree based on
`54c8d907ce830930a3527c57207572f13d049e74`. The final release commit does not
exist yet.

## Release decision

The package boundary is appropriate for a first release: it contains Membrane
transport and RawVideo conversion only, depends on published `video_interop`
0.1, and contains no native implementation.

Do not tag yet. The repository has no configured remote, is not publicly
reachable at its declared GitHub URL, and has uncommitted release work.
Exact-tag CI and the protected Hex publication environment therefore cannot
run.

## Findings addressed

### Registry dependency

The sibling VideoInterop path override was removed. `mix.exs` now declares
`{:video_interop, "~> 0.1.0"}`, and `mix.lock` records published Hex version
0.1.0.

### Ownership documentation

The source now states that a matching ingress message transfers ownership and
that invalid, replaced, and pending shutdown frames are released. The sink now
states that every normal callback return consumes the frame, while exceptions,
exits, and throws are released by the sink. A callback must not transfer
ownership and then raise.

### RawVideo conversion boundary

RawVideo conversion now validates inputs instead of allowing malformed formats
to raise during arithmetic or frame construction. Conversion rejects unaligned
input, unsupported framerates, partial visible rectangles, non-progressive or
non-square formats, and RGBA frames whose alpha is not straight. Padded rows are
compacted through iodata rather than repeated binary accumulation.

### Package and release automation

The project now pins its current Erlang/Elixir development toolchain, includes
the complete Apache-2.0 text with project-specific attribution, includes
changelog and license pages in generated docs, verifies Hex advisories in CI,
and compiles the unpacked package in production mode from registry dependencies.

A protected `publish-hex` job runs only for `v*` tags in the canonical GitHub
repository, depends on the complete test/package matrix and exact-tag gate, and
publishes the package and documentation separately.

## Remaining release blockers

1. Create the `emerge-elixir/membrane_video_interop` GitHub repository, configure
   `origin`, push `main`, and make it publicly accessible.
2. Create a protected GitHub environment named `hex`, restricted to tag rules
   matching `v*`, with reviewer approval.
3. Add a short-lived `HEX_API_KEY` environment secret with API write permission.
4. Review and commit the current candidate.
5. Run the full validation matrix from the final clean commit.
6. Confirm the recorded `2026-09-03` release date is still correct.
7. Push annotated tag `v0.1.0`, wait for all tag checks, then approve the
   protected publication deployment.

The Hex API currently returns 404 for `membrane_video_interop`; the name is
available but not reserved. Recheck immediately before publication.

## Validation matrix

```sh
mix deps.get
mix format --check-formatted
mix compile --force --warnings-as-errors
mix test --warnings-as-errors
mix docs --warnings-as-errors
mix hex.audit
mix hex.build --unpack --output /tmp/membrane_video_interop-0.1.0
```

Repeat compile and test on Elixir 1.17/OTP 27. Compile the unpacked package with
`MIX_ENV=prod` after fetching registry dependencies.

Current results:

- 22 tests pass on Elixir 1.17.3/OTP 27.3.4.3 and Elixir 1.20.2/OTP 29.0.5;
- the same suite passes with minimum dependencies `membrane_core 1.2.0` and
  `membrane_raw_video_format 0.4.0`;
- built-in line coverage is 97.8%;
- formatting, warnings-as-errors compilation, ExDoc, Hex advisory audit, and
  workflow lint pass;
- all direct dependencies are current within their declared requirements;
- the package contains 8 files and 28,428 unpacked bytes, with no build output,
  tests, maintainer plans, native code, or path dependencies;
- the unpacked package compiles in production mode using registry-only
  dependencies.

The current provisional archive is 14,336 bytes with SHA-256
`a2323bb0011c6109f8877abf22640b4c9ee15dcf361d3a7522b731650abf2e45`.
Recompute this from the final clean release commit.

A fresh dependency compilation on Elixir 1.20 reports an upstream deprecation
from transitive `qex 0.5.2`; project compilation remains warning-free and the
warnings-as-errors gate passes. This is not a package-local release blocker.

## Post-publication verification

1. Fetch `{:membrane_video_interop, "== 0.1.0"}` in a clean Mix project.
2. Compile with warnings denied and run a minimal source-to-sink pipeline.
3. Verify HexDocs and source links.
4. Create the GitHub release from the same tag.
5. Replace downstream `membrane_video_interop` path dependencies and regenerate
   locks only after the registry artifact passes.
