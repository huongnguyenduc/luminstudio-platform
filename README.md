# Lumin Studio

Lumin Studio is a 3D commerce platform composed of an admin web application,
a Go API gateway, an asynchronous Rust 3D worker, and a Flutter customer
application. PostgreSQL, MinIO, NATS, and Meilisearch provide persistence,
object storage, event delivery, and search.

## Current Status

Phase 0 established the product contract and monorepo foundation. Phase 1 is in
progress: the Go API has an operational health endpoint, and the Rust worker
has an executable startup/configuration target. The React + Vite Web Admin has
an executable build/test target and a non-product shell. A repeatable local
K3d cluster now hosts the labeled `dev` namespace and a healthy namespace-local
NATS service plus persistent PostgreSQL, MinIO, and Meilisearch instances. The
Bazel-built Go API image runs behind a namespace-local Service and exposes
separate liveness and platform-readiness endpoints that prove connectivity to
all four services. A repeatable in-cluster NATS publish/subscribe smoke command
also proves message transport through the namespace-local Service. MinIO
development buckets for source GLB, optimized GLB, and 360-degree sprite assets
are bootstrapped idempotently in the dev namespace, and Traefik host routes
expose MinIO administration plus Meilisearch inspection for local development.
The first Phase 2 shared product, asset, and event contracts plus the Go API
product validation and PostgreSQL product schema foundation are implemented.
The Go API now exposes the first runtime admin product creation route,
`POST /admin/products`, backed by the product store. Admin product read routes
now expose persisted records through `GET /admin/products` and
`GET /admin/products/{id}`. Admin product update now exposes full-replacement
updates through `PUT /admin/products/{id}`. Admin product create and update
mutations now publish v1 `product.updated` events through NATS for later
asynchronous search synchronization. The first product search-sync consumer now
handles `product.updated` events and upserts derived product documents into the
Meilisearch `products` index. The Go API now exposes the first source GLB
upload route, stores source assets in MinIO, queues product processing state,
and publishes `3d.task.created` for later worker processing. The Rust worker
now parses and validates v1 `3d.task.created` events and hands the referenced
source GLB object to a source asset reader before mesh optimization or
rendering. The worker now also uses the upstream-recommended Rust `meshopt`
crate to simplify supported indexed triangle primitives in GLB 2.0 assets while
preserving scene, node, and material metadata. The supplied pet-tag fixture
provides repeatable native and Bazel proof for this mesh optimization boundary.
Blender 4.5 LTS is now the selected headless 360-degree renderer, and the
pet-tag fixture proves deterministic 24-frame, 6-by-4 JPEG sprite generation
with the locally installed compatible Blender build. The worker runtime now
composes source download, mesh optimization, Blender rendering, processed
MinIO uploads, and v1 `3d.task.completed` publication behind testable ports.
The Go API now consumes valid worker completion events and atomically records
the optimized GLB, sprite sheet, and completed processing state in PostgreSQL.
The Rust worker now has a local development container image and K3d Deployment,
and an isolated live smoke proves source upload through the Go API, NATS task
delivery, worker processing, MinIO processed uploads, completion publication,
and API completion consumption. Production worker image hardening and
retry/dead-letter behavior remain deferred. The first Phase 3 customer-facing
catalog/search API routes now expose `GET /catalog/products` and
`GET /catalog/search?q=...` through the Go API gateway, backed by the derived
Meilisearch `products` index. The Flutter customer app now has an executable
Android/iOS shell with Home, Category, and Cart tabs plus retained tab scroll
and navigation state. The Flutter Home tab now loads catalog product cards from
the Go API `GET /catalog/products` boundary with loading, empty, failure, and
ready states. The Flutter Home tab also submits catalog searches to the Go API
`GET /catalog/search?q=...` boundary with loading, empty, failure/retry, clear,
and ready states. Category taxonomy, 360-degree preview activation, product
detail, signed object URLs, cart persistence, and auth remain deferred.

The original [SPEC.md](SPEC.md) is input material. Current product truth lives
under `docs/product/`, selected work lives under `docs/stories/`, and proof
status is queried through the Harness CLI. Dependency attribution is recorded
in [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md).

## Repository Map

```text
apps/
  mobile-flutter/       Customer Flutter application
  web-admin/            React and Vite administration application
services/
  api-gateway/          Go API and event coordination
  worker-3d/            Rust worker and 3D processing boundary
packages/
  shared-types/         API, event, and schema contracts
  third-party/          Reviewed native third-party sources
infra/
  k8s/                  Kustomize resources for the dev cluster
  scripts/              Deployment and operational scripts
.agents/skills/         Optional UI design and image-direction skills
```

## Start Here

1. Read [AGENTS.md](AGENTS.md).
2. Read the relevant files under [docs/product](docs/product/README.md).
3. Select or create a story under [docs/stories](docs/stories/README.md).
4. Check proof state with `scripts/bin/harness-cli query matrix`.

Phase 0 structural verification:

```bash
bash scripts/verify-foundation.sh
```

First Phase 1 component verification:

```bash
bash scripts/verify-us-001.sh
```

Rust worker bootstrap verification:

```bash
bash scripts/verify-us-002.sh
```

Web Admin bootstrap verification:

```bash
bash scripts/verify-us-003.sh
```

Kustomize development namespace verification:

```bash
bash scripts/verify-us-004.sh
```

K3d development cluster lifecycle verification:

```bash
bash scripts/verify-us-005.sh
```

NATS development deployment verification:

```bash
bash scripts/verify-us-006.sh
```

PostgreSQL development deployment verification:

```bash
bash scripts/verify-us-007.sh
```

MinIO development deployment verification:

```bash
bash scripts/verify-us-008.sh
```

Meilisearch development deployment verification:

```bash
bash scripts/verify-us-009.sh
```

Go API image and K3d deployment verification:

```bash
bash scripts/verify-us-010.sh
```

Go API platform connectivity verification:

```bash
bash scripts/verify-us-011.sh
```

NATS publish/subscribe smoke verification:

```bash
bash scripts/verify-us-012.sh
```

MinIO development bucket verification:

```bash
bash scripts/verify-us-013.sh
```

Local development route verification:

```bash
bash scripts/verify-us-014.sh
```

Phase 2 product contract verification:

```bash
bash scripts/verify-us-015.sh
```

Product persistence foundation verification:

```bash
bash scripts/verify-us-016.sh
```

Admin product HTTP API verification:

```bash
bash scripts/verify-us-017.sh
```

Admin product read API verification:

```bash
bash scripts/verify-us-018.sh
```

Admin product update API verification:

```bash
bash scripts/verify-us-019.sh
```

Admin product mutation event publication verification:

```bash
bash scripts/verify-us-020.sh
```

Product search synchronization verification:

```bash
bash scripts/verify-us-021.sh
```

Admin source GLB upload and task event verification:

```bash
bash scripts/verify-us-022.sh
```

Worker task event and source download foundation verification:

```bash
bash scripts/verify-us-023.sh
```

GLB mesh optimization foundation verification:

```bash
bash scripts/verify-us-024.sh
```

360-degree sprite rendering verification:

```bash
bash scripts/verify-us-025.sh
```

Worker runtime processing and output upload verification:

```bash
bash scripts/verify-us-026.sh
```

API processing completion consumption verification:

```bash
bash scripts/verify-us-027.sh
```

Worker K3d deployment and live processing smoke verification:

```bash
bash scripts/verify-us-028.sh
```

Customer catalog/search API verification:

```bash
bash scripts/verify-us-029.sh
```

Flutter customer app shell verification:

```bash
bash scripts/verify-us-030.sh
```

Flutter catalog products API integration verification:

```bash
bash scripts/verify-us-031.sh
```

Flutter catalog search UI integration verification:

```bash
bash scripts/verify-us-032.sh
```

Bazel is the selected top-level build system. Go, Rust, JavaScript, and OCI
rules now provide executable component and API image targets; Flutter rules and
remaining platform behavior will be added by later stories.
