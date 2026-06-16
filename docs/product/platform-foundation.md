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
  Vite target. The Flutter customer app now has a native Flutter Android/iOS
  shell with `flutter analyze` and `flutter test` proof, but Flutter Bazel
  rules must still be introduced before `bazel build //...` becomes a
  repository-wide acceptance claim.

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
`US-026` wires the worker runtime processing boundary through source download,
mesh optimization, Blender rendering, MinIO processed asset uploads, and
`3d.task.completed` publication with unit and Bazel proof, without adding
worker image packaging, live K3d deployment, retries, or API completion
consumption.
`US-027` adds the API completion consumer, which validates
`3d.task.completed` and atomically records both processed asset references plus
completed product state without adding live K3d proof or retry/dead-letter
semantics.
`US-028` packages the Rust worker as a local development image, deploys it to
K3d, and proves one live processing path from API source upload through NATS,
worker processing, MinIO processed uploads, completion publication, and API
completion consumption without adding production image hardening,
retry/dead-letter behavior, auth, UI, mobile, or customer catalog/search
routes.
`US-029` starts Phase 3 by exposing customer catalog/search HTTP routes through
the Go API gateway. The routes query the derived Meilisearch `products` index
and return v1 customer catalog item response shapes without adding Flutter UI,
category taxonomy, sorting, signed object URLs, product detail, auth,
retry/dead-letter behavior, or live K3d proof.
`US-030` adds the first executable Flutter customer app shell for Android and
iOS with Home, Category, and Cart tabs plus retained tab scroll and nested
navigation state, without adding catalog API integration, search, 360-degree
previews, product detail, cart persistence, Flutter Bazel rules, or live device
proof.
`US-031` adds Flutter catalog products API integration through the existing Go
API `GET /catalog/products` boundary and renders Home tab product cards with
loading, empty, and failure states, without adding search UI, category behavior,
360-degree preview activation, product detail, cart persistence, Flutter Bazel
rules, or live device proof.
`US-032` adds Flutter catalog search UI integration through the existing Go API
`GET /catalog/search?q=...` boundary and renders Home tab search loading,
empty, failure/retry, clear, and result states, without adding category
behavior, 360-degree preview activation, product detail, cart persistence,
Flutter Bazel rules, or live device proof.
`US-033` adds Flutter Home tab pagination for both catalog browsing and search
results through the existing Go API `limit` and `offset` parameters, with
append behavior, end-of-list messaging, and inline retry for incremental load
failures, without adding category behavior, sorting controls, 360-degree
preview activation, product detail, cart persistence, Flutter Bazel rules, or
live device proof.
`US-034` adds the first customer sprite asset access route,
`GET /catalog/products/{id}/sprite`, through the Go API gateway. The route
checks the authoritative PostgreSQL product row and streams only completed
`lumin-360-sprites` JPEG assets from MinIO, without adding signed URLs, direct
client storage access, Flutter preview activation, product detail, auth, or
live K3d proof.
`US-035` activates those sprite assets in the Flutter Home tab after a catalog
card is at least 80% visible and idle for three seconds. Preview rendering
still goes through the Go API sprite route and does not add direct storage
access, signed URLs, product detail, cart persistence, Flutter Bazel rules, or
live device proof.
`US-036` starts Phase 4 product detail by adding
`GET /catalog/products/{id}?tier=low|high` and
`GET /catalog/products/{id}/model?tier=low|high` through the Go API gateway.
The detail route returns seller-provided sections, mesh color configuration,
sprite/model gateway routes, and the selected model asset after the API reads
the authoritative PostgreSQL row. The model route streams completed low-tier
optimized GLB output or high-tier source GLB bytes from MinIO without exposing
direct storage access, signed URLs, Flutter viewer behavior, cart persistence,
or live device proof.
`US-037` connects the Flutter Home tab to the product-detail boundary. Catalog
cards now open a detail screen that resolves a low/high model tier locally and
requests product detail through the Go API repository/use-case boundary. The
screen displays seller-provided sections, mesh color configuration, and
gateway model/sprite route metadata while keeping direct storage/search/message
access, interactive viewer behavior, cart persistence, Flutter Bazel rules,
and live device proof deferred.
`US-038` adds the first interactive Flutter product model viewer on that detail
screen. The viewer consumes only the API gateway model route selected by the
existing detail response and enables rotate/zoom controls through the chosen
WebView-backed Flutter bridge, while keeping material editing, cart
persistence, direct storage/search/message access, Flutter Bazel rules, and
live device proof deferred.
`US-039` adds customer material color selection to the same detail screen using
the existing `meshColorConfig` response. Selection remains local Flutter state
inside `ProductDetailCubit`, keeps direct storage/search/message access out of
the app, and leaves cart persistence, Flutter Bazel rules, and live device
proof deferred.
`US-040` adds the first local Flutter cart persistence slice. Product Detail can
add the selected product configuration to a local cart repository, and the Cart
tab renders stored product identity, selected mesh colors, quantity, and
selection state without introducing backend cart APIs, checkout, payment,
inventory, direct storage/search/message access, Flutter Bazel rules, or live
device proof.
`US-041` adds a required display price contract to product drafts and records,
propagates that price through the API-owned search/catalog/detail boundary, and
lets the local Flutter cart calculate selected subtotal and savings from stored
price snapshots without introducing checkout, payment, auth, inventory,
backend cart APIs, direct storage/search/message access, Flutter Bazel rules,
or live device proof.

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
- Production worker image packaging approach for the pinned Blender 4.5 LTS
  runtime.
- Flutter 3D viewer and JavaScript/native bridge implementation.
- Event schema format and compatibility/versioning policy.
