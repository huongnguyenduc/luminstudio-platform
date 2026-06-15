# US-023 Worker Task Created Source Download

## Status

implemented

## Lane

normal

## Product Contract

The Rust worker can consume a v1 `3d.task.created` payload at its component
boundary, reject malformed or out-of-contract events, and request the referenced
source GLB object from a source asset reader. This establishes the worker-side
handoff from API task publication to source asset intake without implementing
mesh optimization, 360-degree rendering, processed asset uploads,
`3d.task.completed` publication, retry/outbox semantics, dead-letter handling,
authentication, authorization, admin UI, customer catalog/search routes, mobile
behavior, or live K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/worker-3d` defines the v1 `3d.task.created` event, source asset,
  and mesh color configuration shapes from the shared event contract.
- The worker parser rejects unknown JSON fields, wrong event type or schema
  version, invalid product/task/correlation identities, invalid source object
  references, and invalid mesh color configuration.
- The worker exposes a `TaskProcessor` that consumes validated task events and
  asks a `SourceAssetReader` for the referenced `lumin-source-glb` object.
- The worker exposes the NATS task subject `lumin.3d.task.created` and a
  core-NATS subscriber boundary for later runtime wiring.
- Verification proves native Rust tests, Bazel worker tests and build, crate
  dependency wiring, docs updates, and story non-goals without requiring live
  K3d MinIO or NATS services.

## Design Notes

- Commands: `bash scripts/verify-us-023.sh`.
- Queries: none; the worker does not read PostgreSQL or update relational state.
- API: none.
- Tables: none.
- Events: consumes `3d.task.created` from subject `lumin.3d.task.created`.
- Objects: source GLB object reference under bucket `lumin-source-glb`.
- Domain rules: source object references and mesh color configuration are parsed
  and validated before later processing code can use them.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-023 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Rust tests cover task event parsing, validation failures, source asset reader handoff, and NATS subject exposure. |
| Integration | Bazel builds and tests the worker target with serde/serde_json crate wiring. |
| E2E | Not required; no browser/mobile workflow exists in this story. |
| Platform | Not required; no live K3d MinIO or NATS proof is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-023.sh` passed.
- Native Rust tests passed for `worker-3d`.
- Bazel tests passed for `//services/worker-3d/...`.
- Bazel built `//services/worker-3d:worker-3d`.
- Static verification found task event parsing, v1 validation, source asset
  reader handoff, task subject exposure, crate dependency wiring, docs updates,
  and story non-goals.
