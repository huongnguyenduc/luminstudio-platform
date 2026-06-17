# US-026 Worker Runtime Processing And Output Upload

## Status

implemented

## Lane

normal

## Product Contract

The Rust worker processes one validated v1 `3d.task.created` event through the
existing GLB optimizer and Blender sprite renderer, uploads both generated
assets to their MinIO buckets, and publishes a v1 `3d.task.completed` event
containing the resulting object references.

This story does not package or deploy the worker image, add live K3d proof,
consume completion events in the Go API, update PostgreSQL, add retries,
outbox/dead-letter behavior, authentication, authorization, admin UI, or mobile
behavior.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The worker composes task parsing, source download, GLB optimization, Blender
  rendering, processed asset upload, and completion publication behind testable
  component boundaries.
- Optimized GLBs are uploaded to `lumin-optimized-glb` as
  `[productId]_low.glb` with `model/gltf-binary` content type.
- Sprite sheets are uploaded to `lumin-360-sprites` as
  `[productId]_360_sprite.jpg` with `image/jpeg` content type.
- The worker publishes a valid v1 `3d.task.completed` event on
  `lumin.3d.task.completed` only after both uploads succeed.
- The completion event preserves task, product, and correlation identities and
  includes uploaded object metadata.
- Unit tests prove orchestration order, failure propagation, object references,
  and completion payload shape; Cargo and Bazel verification pass.

## Design Notes

- Commands: `bash scripts/verify-us-026.sh`.
- Queries: none; the worker does not access PostgreSQL.
- API: none.
- Tables: none.
- Events: consumes `3d.task.created`; publishes `3d.task.completed`.
- Objects: reads `lumin-source-glb`; writes `lumin-optimized-glb` and
  `lumin-360-sprites`.
- Domain rules: completion is published only after both processed objects are
  durably accepted by the object store adapter.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-026 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Rust tests cover successful orchestration, output metadata, completion JSON, and upload/publish failures. |
| Integration | Cargo and Bazel compile and test the worker with MinIO, NATS, optimizer, and renderer wiring. |
| E2E | Not required; API completion consumption is a later story. |
| Platform | Not required; worker image packaging and live K3d deployment are deferred. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-026.sh` passed.
- Cargo formatting and Clippy with warnings denied passed.
- All 23 native Rust tests passed, including raw event-to-completion pipeline
  composition and failure propagation coverage.
- Bazel worker tests and the `//services/worker-3d:worker-3d` build passed with
  the pinned MinIO SDK, Tokio runtime, optimizer, and renderer wiring.
- Regression verifiers `US-023`, `US-024`, and `US-025` passed; the Blender
  fixture remained byte-identical across two renders.
