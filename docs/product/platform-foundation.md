# Platform Foundation

## Component Ownership

| Path | Technology | Responsibility |
| --- | --- | --- |
| `apps/web-admin` | React + Vite | Product administration and asset upload UI |
| `apps/mobile-flutter` | Flutter + BLoC | Customer catalog, 3D detail, and cart |
| `services/api-gateway` | Go | Business API, persistence, storage coordination, and event publication |
| `services/worker-3d` | Rust + C++ FFI | Mesh optimization, 360 rendering, and processed asset upload |
| `packages/shared-types` | Protobuf/OpenAPI/JSON Schema | Versioned contracts shared across components |
| `packages/third-party` | Native sources/metadata | Reviewed native dependencies such as meshoptimizer |
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
indexed document survives pod replacement. These stories do not satisfy the
complete Phase 1 acceptance contract above; storage buckets, external
development routes, application connectivity, and publish/subscribe proof
remain outstanding.

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
- Headless renderer used for 360-degree sprite generation.
- Flutter 3D viewer and JavaScript/native bridge implementation.
- Event schema format and compatibility/versioning policy.
