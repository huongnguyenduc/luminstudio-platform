# US-025 Worker 360-Degree Sprite Rendering

## Status

implemented

## Lane

normal

## Product Contract

The 3D worker has a selected headless renderer and can transform a GLB into a
deterministic 24-frame JPEG sprite sheet using a fixed camera orbit, lighting
setup, frame size, and 6-by-4 layout. Output naming follows
`[productId]_360_sprite.jpg`.

This story does not add MinIO output upload, runtime NATS subscriber wiring,
`3d.task.completed` publication, API completion consumption, retry semantics,
worker image packaging, authentication, authorization, admin UI, mobile
behavior, or live K3d proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Decision `0012` selects Blender 4.5 LTS headless CLI and Python automation.
- The worker owns a Blender script that imports a GLB, rejects empty assets,
  computes world bounds, uses a fixed EEVEE camera and lighting setup, and
  writes one JPEG sprite sheet.
- The initial sprite contract uses 24 frames, 160-by-160 pixels per frame, six
  columns, four rows, and the `[productId]_360_sprite.jpg` naming convention.
- Unit tests cover the Rust-side sprite contract and output naming validation.
- Verification renders the supplied pet-tag fixture twice with one installed
  Blender build and proves identical bytes and expected dimensions.
- Cargo and Bazel worker tests pass without adding storage, events, API, UI, or
  live-cluster behavior.

## Design Notes

- Commands: `bash scripts/verify-us-025.sh`.
- Queries: none.
- API: none.
- Tables: none.
- Events: none added; completion publication remains deferred.
- Objects: deterministic sprite key `[productId]_360_sprite.jpg`; upload is deferred.
- Domain rules: repeatability is scoped to the same Blender build, platform,
  script, asset, and render configuration.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-025 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Rust tests cover sprite constants and output naming. |
| Integration | Blender renders the fixture twice to identical 960-by-640 JPEG files; Cargo and Bazel worker tests pass. |
| E2E | Not required; storage and completion flow are out of scope. |
| Platform | Not required; worker image and live K3d execution are deferred. |
| Release | Not required. |

## Harness Delta

Register the locally installed Blender executable under the `3d-rendering`
capability when present. Absence remains a clean skip for assessment, but the
story verifier requires Blender because rendered fixture proof is mandatory.

## Evidence

- `bash scripts/verify-us-025.sh` passed with Blender 5.0.1 compatibility proof.
- The pet-tag fixture rendered twice to byte-identical 960-by-640 JPEG sheets.
- Cargo formatting, Clippy, native worker tests, Bazel worker tests, and the
  renderer script Bazel target passed.
