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
- `US-009 Deploy Meilisearch in the dev cluster` adds the persistent derived
  search service without product indexes, external routing, synchronization,
  or API connectivity.
- `US-010 Deploy the Go API in the dev cluster` starts E03 with Bazel-built OCI
  images, a namespace-local application workload, and in-cluster health proof
  without platform connectivity or product behavior.
- `US-011 Connect the Go API to platform services` adds environment-backed
  PostgreSQL, MinIO, NATS, and Meilisearch connectivity with separate liveness
  and readiness behavior, without adding product data or event contracts.
- `US-012 NATS publish subscribe smoke` proves that a client pod can publish
  and receive a smoke payload through the namespace-local NATS Service without
  adding product event schemas, JetStream persistence, worker behavior, or API
  publication.
- `US-013 Create MinIO development buckets` adds idempotent source and
  processed asset buckets without product upload API behavior, object key
  policy, worker behavior, or external routing.
- `US-014 Local development routes` exposes MinIO administration and
  Meilisearch through Traefik host routes without adding public API routing,
  product workflows, or production ingress topology.

## Phase 2: Admin, API, And 3D Pipeline

Goal: implement product administration, search synchronization, and processed
3D asset generation.

- Epic `E04`: Product management and dynamic information sections.
- Epic `E05`: GLB upload and mesh color configuration.
- Epic `E06`: Event-driven Meilisearch synchronization.
- Epic `E07`: Rust processing and completion flow.

Selected work:

- `US-015 Define Phase 2 Product, Asset, And Event Contracts` starts E04 with
  versioned JSON Schema sources for initial product administration records,
  MinIO asset references, mesh color configuration, and the first product and
  processing events without adding runtime API, persistence, worker, search, or
  UI behavior.
- `US-016 Product Persistence Foundation` adds the first Go API product domain
  validation package and PostgreSQL `products` schema for product records,
  dynamic information sections, mesh color configuration, asset references, and
  processing status without adding HTTP routes, uploads, events, search, worker,
  or UI behavior.
- `US-017 Admin Product HTTP API` exposes `POST /admin/products` through the Go
  API, validates the v1 product draft shape at the HTTP boundary, generates a
  server-side product identity, and persists through the product store without
  adding uploads, events, search synchronization, worker processing, auth, or
  UI behavior.
- `US-018 Admin Product Read HTTP API` exposes `GET /admin/products` and
  `GET /admin/products/{id}` through the Go API so admin clients can read
  persisted records from PostgreSQL without adding updates, uploads, events,
  search synchronization, worker processing, auth, or UI behavior.
- `US-019 Admin Product Update HTTP API` exposes `PUT /admin/products/{id}` as
  a full-replacement update for persisted product drafts without adding delete
  workflows, uploads, events, search synchronization, worker processing, auth,
  or UI behavior.
- `US-020 Admin Product Mutation Event Publication` publishes v1
  `product.updated` events after successful admin product creation and
  full-replacement update persistence without adding search synchronization,
  uploads, worker processing, retry/outbox semantics, auth, or UI behavior.
- `US-021 Product Search Synchronization` consumes v1 `product.updated` events,
  reads the authoritative product record from PostgreSQL, and upserts a derived
  document into the Meilisearch `products` index without adding catalog/search
  HTTP routes, mobile UI, uploads, worker processing, retry/outbox semantics,
  auth, or live K3d proof.
- `US-022 Admin Source GLB Upload And Task Event` exposes
  `POST /admin/products/{id}/source-glb`, stores one source `.glb` in the
  `lumin-source-glb` MinIO bucket, updates the product source asset and queued
  processing status, and publishes `3d.task.created` without adding admin UI,
  worker processing, processing completion consumption, retry/outbox semantics,
  auth, or live K3d proof.
- `US-023 Worker Task Created Source Download` starts E07 by parsing and
  validating v1 `3d.task.created` events in the Rust worker, exposing the
  `lumin.3d.task.created` subscription boundary, and handing the referenced
  `lumin-source-glb` object to a source asset reader without adding
  meshoptimizer, 360-degree rendering, processed asset uploads,
  `3d.task.completed` publication, retry/outbox semantics, auth, UI, or live
  K3d proof.
- `US-024 Worker GLB Mesh Optimization` uses the pinned Rust `meshopt` crate to
  simplify supported GLB 2.0 indexed triangle primitives, preserve scene and
  material metadata, rebuild a valid smaller binary asset, and verify the
  supplied pet-tag fixture without adding 360-degree rendering, MinIO upload,
  runtime task wiring, completion publication, retry semantics, auth, or UI.
- `US-025 Worker 360-Degree Sprite Rendering` selects Blender 4.5 LTS headless
  automation and proves a deterministic 24-frame, 6-by-4 JPEG sprite sheet
  against the supplied GLB fixture without adding worker image packaging,
  MinIO upload, runtime task wiring, completion publication, auth, or UI.

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
