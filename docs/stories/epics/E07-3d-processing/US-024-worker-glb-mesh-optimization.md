# US-024 Worker GLB Mesh Optimization

## Status

implemented

## Lane

normal

## Product Contract

The Rust worker can simplify supported indexed triangle primitives in a GLB 2.0
source asset through the pinned `meshopt` crate, rebuild a valid smaller GLB,
and preserve scene, node, mesh, and material metadata. Unsupported or ambiguous
buffer layouts fail before producing output.

This story does not add 360-degree rendering, MinIO output upload, runtime NATS
subscriber wiring, `3d.task.completed` publication, API completion consumption,
retry/outbox semantics, dead-letter handling, authentication, authorization,
admin UI, mobile behavior, or live K3d proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/worker-3d` pins `meshopt` 0.6.2 and uses its Rust simplification API.
- The optimizer validates the GLB 2.0 header, JSON/BIN chunks, embedded buffer,
  triangle primitive mode, POSITION accessor shape, and index accessor layout.
- Supported u16/u32 index buffers are simplified and the GLB binary plus JSON
  offsets, lengths, and accessor counts are rebuilt consistently.
- Invalid, sparse, shared, non-triangle, or unsupported component layouts are
  rejected instead of producing a partial asset.
- Output naming follows `[productId]_low.glb`.
- `resources/pet_tag.glb` proves two primitives are reduced while `Tag_Base`,
  `Tag_Text`, `Base_Mat`, and `Text_Mat` remain present.
- Cargo and Bazel tests/builds pass through one mechanical verifier.

## Design Notes

- Commands: `bash scripts/verify-us-024.sh`.
- Queries: none.
- API: none.
- Tables: none.
- Events: none added; runtime task processing remains deferred.
- Objects: deterministic optimized object key `[productId]_low.glb`; upload is
  deferred.
- Domain rules: parse and validate unknown GLB bytes before simplification.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-024 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Config, invalid header, output naming, supported layout, and metadata preservation tests. |
| Integration | Cargo and Bazel compile the pinned crate and optimize the supplied GLB fixture. |
| E2E | Not required; storage and event runtime wiring are out of scope. |
| Platform | Not required; no live K3d worker deployment is added. |
| Release | Not required. |

## Harness Delta

The user-supplied GLB and description are registered as deterministic repository
fixtures for later 3D processing stories.

## Evidence

- `bash scripts/verify-us-024.sh` passed.
- Native Rust tests passed for `worker-3d`.
- Bazel worker tests and `optimize-glb` build passed.
- The fixture optimization reduced both triangle primitives and emitted a
  smaller GLB while preserving required node and material names.
