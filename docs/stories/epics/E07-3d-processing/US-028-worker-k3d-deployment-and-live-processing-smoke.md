# US-028 Worker K3d Deployment And Live Processing Smoke

## Status

implemented

## Lane

normal

## Product Contract

The Rust 3D worker is packaged as a local development container image, deployed
into the K3d `dev` namespace, and proven against the live API, PostgreSQL,
MinIO, NATS, and Meilisearch platform by processing one uploaded GLB fixture
from `queued` to `completed`.

This story packages a Linux arm64 development image with Debian's Blender
runtime for local K3d proof. It does not settle the production pinned Blender
4.5 LTS image approach, add retry/outbox semantics, failure events,
dead-letter handling, authentication, authorization, UI, mobile behavior, or
customer catalog/search routes.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The worker has a long-running runtime mode for Kubernetes deployment while
  preserving the existing one-shot runtime mode for focused verification.
- A local development worker image builds from `services/worker-3d/Dockerfile`
  and includes the Rust `worker-3d` binary, Blender, and the repository
  360-degree render script.
- The development overlay deploys one `worker-3d` replica with NATS, MinIO,
  Blender, and writable temporary-directory configuration.
- A repeatable import script builds `lumin/worker-3d:dev` and imports it into
  the selected K3d cluster.
- The live verifier creates an isolated K3d cluster, imports API and worker
  images, applies the dev overlay, applies the product migration, creates a
  product through the Go API, uploads `resources/pet_tag.glb` through the Go
  API, and waits until the API product record reports `completed`.
- The completed product record references `lumin-optimized-glb` and
  `lumin-360-sprites` objects using the v1 processed asset naming convention.

## Design Notes

- Commands: `bash scripts/verify-us-028.sh`.
- Queries: one live `GET /admin/products/{id}` polling loop observes
  processing completion through the API boundary.
- API: uses existing `POST /admin/products`,
  `POST /admin/products/{id}/source-glb`, and `GET /admin/products/{id}`.
- Tables: applies the existing `products` migration in the isolated verifier
  before the live API smoke.
- Events: uses existing `lumin.3d.task.created` and
  `lumin.3d.task.completed` subjects.
- Domain rules: the worker writes processed objects and publishes completion;
  the Go API remains the only component that mutates PostgreSQL product state.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-028 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Worker Cargo tests cover runtime mode separation and existing pipeline behavior. |
| Integration | Bazel worker tests and manifest/script builds pass; the worker image starts and exposes Blender. |
| E2E | Not required; no browser/mobile user flow is introduced. |
| Platform | Isolated K3d smoke proves API upload, NATS task delivery, worker processing, MinIO processed uploads, completion publication, and API completion consumption. |
| Release | Not required for local development image packaging. |

## Harness Delta

None expected.

## Evidence

- `cargo test -p worker-3d` passed with 24 worker tests.
- `bazelisk test //services/worker-3d/...` passed.
- `bazelisk build //infra/k8s:dev-manifests //infra/scripts:dev-cluster //infra/scripts:import-api-image //infra/scripts:import-worker-image` passed.
- `bash scripts/verify-us-028.sh` passed, including the isolated
  `lumin-worker-live-verify-13744` K3d live smoke for
  `prod_ACR8tY0k65oJ1otZtF3thrGt`.
- `scripts/bin/harness-cli story verify US-028` passed, including the isolated
  `lumin-worker-live-verify-16256` K3d live smoke for
  `prod_I_iIHHCWK0gnV13YIgUPcdTA`.
