# Platform Foundation

## Component Ownership

| Path | Technology | Responsibility |
| --- | --- | --- |
| `apps/web-admin` | React + Vite | Product administration and asset upload UI |
| `apps/mobile-flutter` | Flutter + BLoC | Customer catalog, 3D detail, and cart |
| `services/api-gateway` | Go | Business API, persistence, storage coordination, and event publication |
| `services/worker-3d` | Rust | Mesh optimization, 360 rendering, and processed asset upload |
| `packages/shared-types` | Protobuf/OpenAPI/JSON Schema | Versioned contracts shared across components |
| `packages/third-party` | Native sources/metadata | Reviewed native dependencies only when a selected story requires them |
| `infra/k8s` | Kustomize/Kubernetes | Dev namespace resources and routing |
| `infra/scripts` | Shell/automation | Repeatable local and CI operational commands |

## Build Contract

- Bazel is the top-level build and test entrypoint.
- Bzlmod through `MODULE.bazel` is the primary external dependency model.
- Each component owns its native package manifest while Bazel defines the
  cross-language build graph.
- Phase 0 created package boundaries only. Phase 1 now pins Bazel 9.1.1,
  `rules_go` 0.61.1 with Go 1.26.4, and `rules_rust` 0.70.0 with Rust 1.95.0
  for the first executable service targets. The Web Admin uses
  `aspect_rules_js` 3.2.1 with Node.js 22.20.0 for its first executable React +
  Vite target. Flutter rules must still be introduced before
  `bazel build //...` becomes a repository-wide acceptance claim.

## Runtime Topology

The local development target is a K3d cluster with a `dev` namespace. Traefik
provides ingress, Cloudflare Tunnel may expose selected routes, and a
self-hosted GitHub runner executes CI/CD jobs near the cluster.

Required platform services:

- PostgreSQL for relational product and processing state.
- MinIO for source GLB, optimized GLB, and 360 sprite assets.
- NATS for asynchronous events and worker task delivery.
- Meilisearch for typo-tolerant product discovery.

## Phase 1 Acceptance Contract

- Web admin, Go API, and Rust worker build targets succeed with their declared
  dependencies.
- PostgreSQL, MinIO, NATS, and Meilisearch run healthy in the K3d `dev`
  namespace.
- MinIO administration and the Meilisearch dashboard are reachable through
  local development routes such as `minio-dev.local` and `search-dev.local`.
- The Go API proves connectivity to PostgreSQL, MinIO, NATS, and Meilisearch.
- A repeatable NATS publish/subscribe smoke command passes.
- MinIO administration and Meilisearch are reachable through local development
  routes.

Current proof is intentionally incremental: `US-001` covers the Go API build,
tests, and operational health endpoint; `US-002` covers the Rust worker build,
tests, and startup/configuration boundary; `US-003` covers the Web Admin build,
tests, and non-product shell; `US-004` introduces the renderable Kustomize
boundary for the `dev` namespace; and `US-005` adds a repeatable local K3d
cluster lifecycle with live namespace proof. `US-006` deploys a healthy core
NATS server behind a namespace-local Service and proves its monitoring health
endpoint from inside the cluster. `US-007` adds a persistent PostgreSQL
StatefulSet and proves that a written value survives pod replacement. `US-008`
adds persistent MinIO object storage and proves that a written object survives
pod replacement. `US-009` adds persistent Meilisearch and proves that an
indexed document survives pod replacement. `US-010` packages the Go API as
Bazel-built Linux amd64 and arm64 OCI images, deploys it behind a
namespace-local Service, and proves the existing health endpoint from inside an
isolated K3d cluster. `US-011` adds required platform configuration and a
separate readiness endpoint that checks PostgreSQL, MinIO, NATS, and
Meilisearch, including failure propagation during a controlled NATS outage.
`US-012` adds a repeatable in-cluster NATS publish/subscribe smoke proof through
the namespace-local Service. `US-013` adds idempotent MinIO development buckets
for source GLB assets, optimized GLB assets, and 360-degree sprite assets.
`US-014` adds local Traefik host routes for MinIO administration and
Meilisearch inspection. `US-015` adds Phase 2 shared product, asset, and event
contract schemas. `US-016` adds the first Go API product validation and
PostgreSQL product schema foundation without applying it to the live K3d
database yet. `US-017` adds the first runtime admin product creation route on
the Go API with unit and Bazel proof, without adding live K3d platform proof,
uploads, event publication, search synchronization, worker behavior, auth, or
UI. `US-018` and `US-019` add admin product read and full-replacement update
routes. `US-020` wires product mutation event publication to NATS with unit and
Bazel proof, without adding live K3d platform proof or search synchronization.
`US-021` adds the first product search-sync consumer and Meilisearch document
upsert path with unit and Bazel proof, without adding live K3d platform proof
or customer search routes. `US-022` adds the first admin source GLB upload API,
MinIO source object write, queued product source state, and
`3d.task.created` event publication with unit and Bazel proof, without adding
live K3d platform proof or worker processing. `US-023` adds the Rust worker
task intake foundation for `3d.task.created`: v1 event parsing, validation,
the `lumin.3d.task.created` subscription boundary, and source asset reader
handoff, without adding live K3d platform proof, mesh optimization, rendering,
processed uploads, or completion publication.
`US-024` adds the first mesh optimization boundary through the pinned Rust
`meshopt` crate. It parses supported GLB 2.0 triangle primitives, simplifies
their index buffers, rebuilds a valid embedded binary buffer, preserves
scene/node/material metadata, and verifies the supplied pet-tag fixture through
Cargo and Bazel without adding renderer, storage, event, or runtime subscriber
wiring.
`US-025` selects Blender 4.5 LTS as the headless sprite renderer and proves a
fixed 24-frame JPEG sprite sheet against the supplied GLB fixture without
adding worker image packaging, storage upload, completion events, runtime task
wiring, or live K3d proof.

## Boundary Rules

- Clients never connect directly to storage, search, messaging, or databases.
- The Go API owns business mutations and relational state transitions.
- The Rust worker consumes task events, writes processed objects to MinIO, and
  reports completion through NATS; it does not update PostgreSQL directly.
- Shared event and API payloads are defined in `packages/shared-types` before
  producers and consumers implement them independently.
- Unknown HTTP, event, environment, and storage payloads are parsed at their
  component boundary before reaching domain/application code.

## Developer Workflow

The target workflow is:

```text
story selected
  -> native component tests
  -> bazel test //...
  -> Bazel-built images
  -> k3d image import
  -> Kustomize apply to dev
  -> platform smoke proof
```

Feature work is developed on bounded branches such as `feature/*`. CI runs on
the self-hosted runner, uses Bazel for test and image construction, imports
images into K3d, and applies the selected Kustomize overlay.

Only steps backed by implemented commands and recorded evidence may be marked
complete in the Harness matrix.

## Open Decisions

- Go HTTP framework: Fiber or Gin.
- Exact Bazel rules and pinned toolchains for Go, Rust, JavaScript, and Dart.
- Exact Blender 4.5 LTS patch and worker image packaging approach.
- Flutter 3D viewer and JavaScript/native bridge implementation.
- Event schema format and compatibility/versioning policy.
