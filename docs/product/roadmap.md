# Delivery Roadmap

The roadmap derives implementation areas from `SPEC.md`. Create story packets
only when work is selected; the candidate list is not proof of implementation.

## Phase 0: Contract And Foundation

Goal: establish living product docs, durable Harness records, monorepo package
boundaries, and a structural validation command.

- Epic `E00`: Product contract and monorepo foundation.
- First story: `US-000 Establish platform foundation`.

## Phase 1: Infrastructure And Event Bus

Goal: make component builds and local platform services operational.

- Epic `E01`: Bazel toolchains and component build targets.
- Epic `E02`: K3d dev namespace with PostgreSQL, MinIO, NATS, and Meilisearch.
- Epic `E03`: Go API connectivity and NATS smoke flow.

Selected work:

- `US-001 Build the Go API and health endpoint` starts E01 with the pinned
  Bazel and Go toolchain plus one executable component target.
- `US-002 Build the Rust worker and startup boundary` adds the executable
  worker target without messaging or 3D dependencies.
- `US-003 Build the Web Admin shell` adds the executable React + Vite target
  without introducing Phase 2 administration workflows.
- `US-004 Create the K3d dev namespace and Kustomize base` starts E02 with a
  renderable deployment boundary but no platform workloads.
- `US-005 Create the K3d development cluster lifecycle` adds repeatable local
  cluster creation, overlay application, status, and deletion without adding
  platform workloads.
- `US-006 Deploy NATS in the dev cluster` is selected to add the first healthy,
  namespace-local platform workload without application connectivity or event
  contracts.
- `US-007 Deploy PostgreSQL in the dev cluster` adds the persistent relational
  system of record without product schema, external routing, or API
  connectivity.
- `US-008 Deploy MinIO in the dev cluster` adds the persistent object storage
  service without buckets, external routing, or API connectivity.

## Phase 2: Admin, API, And 3D Pipeline

Goal: implement product administration, search synchronization, and processed
3D asset generation.

- Epic `E04`: Product management and dynamic information sections.
- Epic `E05`: GLB upload and mesh color configuration.
- Epic `E06`: Event-driven Meilisearch synchronization.
- Epic `E07`: Rust/C++ processing and completion flow.

## Phase 3: Mobile Catalog And Search

Goal: deliver persistent tab navigation, catalog browsing, 360 previews, and
typo-tolerant search.

- Epic `E08`: Flutter application shell and BLoC architecture.
- Epic `E09`: Catalog/category pagination and preview behavior.
- Epic `E10`: Mobile search integration.

## Phase 4: 3D Detail And Cart

Goal: adapt 3D delivery to device capability and support configurable products
in a local cart.

- Epic `E11`: Device-tier detection and 3D product viewer.
- Epic `E12`: Product configuration and related content.
- Epic `E13`: Persistent cart calculations.

## Deferred

- Authentication and authorization.
- Payments, checkout, and order fulfillment.
- Production hosting topology beyond the existing local K3d environment.
