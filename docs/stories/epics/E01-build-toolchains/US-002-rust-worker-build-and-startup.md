# US-002 Build The Rust Worker And Startup Boundary

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a pinned Rust Bazel toolchain and executable 3D
worker target so that Phase 1 proves the worker component can build, test, and
reject invalid startup configuration before messaging or 3D dependencies are
introduced.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Bzlmod declares `rules_rust` and a pinned downloaded Rust toolchain.
- `//services/worker-3d:worker-3d` builds successfully.
- Native Cargo and Bazel tests cover default, valid, and invalid concurrency.
- Startup emits structured component, status, and concurrency fields.
- Invalid `WORKER_CONCURRENCY` input is rejected before worker startup.
- No NATS, MinIO, C++ FFI, renderer, or 3D processing dependency is added.

## Design Notes

- Commands: `bash scripts/verify-us-002.sh`.
- Queries: none.
- API: no network API is introduced.
- Tables: none.
- Domain rules: none; this story is component bootstrap only.
- UI surfaces: none.
- Build: `rules_rust` 0.70.0, Rust 1.95.0, edition 2024.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Configuration parsing and startup formatting tests pass. |
| Integration | Cargo and Bazel compile and test the worker package. |
| E2E | Not applicable; no user-facing workflow exists. |
| Platform | Bazel builds the executable with the pinned downloaded toolchain. |
| Release | Deferred until worker images and K3d resources exist. |

## Harness Delta

- Registered local Git, Cargo, and Bazelisk capabilities in the durable tool registry.
- Added a repeatable story verification command.
- Recorded Harness backlog #2 because `decision add` cannot refresh an existing decision row.

## Evidence

- `cargo test -p worker-3d`: pass; 4 unit tests passed.
- `bazelisk test //services/worker-3d/...`: pass; worker library tests passed.
- `bazelisk build //services/worker-3d:worker-3d`: pass.
- Built binary startup with `WORKER_CONCURRENCY=2`: pass with structured ready output.
- Built binary startup with `WORKER_CONCURRENCY=0`: rejected with exit status 2.
- `scripts/bin/harness-cli story verify US-002`: pass.
