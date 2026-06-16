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
- `US-026 Worker Runtime Processing And Output Upload` composes source download,
  mesh optimization, Blender rendering, processed MinIO uploads, and v1
  `3d.task.completed` publication without adding worker image packaging, live
  K3d deployment, API completion consumption, retries, auth, or UI.
- `US-027 API Processing Completion Consumption` consumes valid v1
  `3d.task.completed` events in the Go API and atomically stores processed asset
  references plus completed processing state without adding worker packaging,
  live K3d proof, retries, outbox/dead-letter behavior, auth, or UI.
- `US-028 Worker K3d Deployment And Live Processing Smoke` packages the Rust
  worker as a local development image, deploys it to K3d, and proves one live
  source upload can complete through API, NATS, worker processing, MinIO
  processed uploads, completion publication, and API completion consumption
  without adding production image hardening, retries, outbox/dead-letter
  behavior, auth, UI, mobile, or customer catalog/search routes.
- `US-045 Web Admin Product List API Integration` adds the first product
  workflow to the React Web Admin by consuming `GET /admin/products` through
  the Go API boundary and rendering loading, empty, failure/retry, and ready
  states without adding product create, edit, delete, source GLB upload, auth,
  direct platform access, or live backend proof.
- `US-046 Web Admin Product Create API Integration` extends the React Web
  Admin product workflow with a create form that submits v1 product drafts to
  `POST /admin/products`, validates client-side fields and JSON sections,
  renders inline success/failure states, and refreshes the product list without
  adding edit, delete, source GLB upload, auth, direct platform access, backend
  contract changes, or live backend proof.
- `US-047 Web Admin Product Edit API Integration` extends the React Web Admin
  product workflow with an edit form that hydrates the selected v1 product
  record, submits a full-replacement draft to `PUT /admin/products/{id}`,
  validates client-side fields and JSON sections, and refreshes the product
  list without adding delete, source GLB upload, auth, direct platform access,
  backend contract changes, or live backend proof.
- `US-048 Web Admin Source GLB Upload API Integration` extends the selected
  React Web Admin product workflow with a source `.glb` upload panel that
  submits multipart `source` files to
  `POST /admin/products/{id}/source-glb`, validates file selection before
  submit, renders inline progress/success/failure states, and refreshes the
  product list without adding delete, auth, direct platform access, backend
  contract changes, signed object URLs, or live backend proof.

## Phase 3: Mobile Catalog And Search

Goal: deliver persistent tab navigation, catalog browsing, 360 previews, and
typo-tolerant search.

- Epic `E08`: Flutter application shell and BLoC architecture.
- Epic `E09`: Catalog/category pagination and preview behavior.
- Epic `E10`: Mobile search integration.

Selected work:

- `US-029 Customer Catalog Search HTTP API` starts Phase 3 with
  customer-facing `GET /catalog/products` and `GET /catalog/search?q=...`
  routes through the Go API, backed by the derived Meilisearch `products` index,
  without adding Flutter UI, category taxonomy, sorting, signed object URLs,
  product detail, auth, retry/outbox behavior, or live K3d proof.
- `US-030 Flutter Customer App Shell` starts E08 with an executable Flutter
  Android/iOS app shell, Home, Category, and Cart bottom navigation, and
  retained tab scroll/navigation state without adding catalog API integration,
  search, category pagination, sorting, 360-degree previews, product detail,
  cart persistence, Flutter Bazel rules, auth, or live device proof.
- `US-031 Flutter Catalog Products API Integration` connects the Flutter Home
  tab to the Go API `GET /catalog/products` route and renders customer-safe
  catalog product cards without adding search UI, category taxonomy, sorting,
  pagination controls, 360-degree preview activation, product detail, signed
  object URLs, cart persistence, auth, Flutter Bazel rules, or live device
  proof.
- `US-032 Flutter Catalog Search UI Integration` exposes Home tab catalog
  search through the Go API `GET /catalog/search?q=...` route and renders
  loading, empty, failure/retry, clear, and ready states without adding category
  taxonomy, sorting, pagination controls, 360-degree preview activation,
  product detail, signed object URLs, cart persistence, auth, Flutter Bazel
  rules, or live device proof.
- `US-033 Flutter Catalog Pagination And Infinite Scroll` extends the Home tab
  catalog and search lists with incremental page loading through the existing
  `limit` and `offset` API parameters, including a pagination footer and inline
  retry state without adding category taxonomy, sorting controls, 360-degree
  preview activation, product detail, signed object URLs, cart persistence,
  auth, Flutter Bazel rules, or live device proof.
- `US-034 Customer Sprite Preview Asset Access API` exposes
  `GET /catalog/products/{id}/sprite` through the Go API gateway. The route
  reads the authoritative PostgreSQL product row, requires completed processing
  and a 360-degree sprite asset reference, and streams the JPEG from MinIO
  without adding Flutter preview activation, product detail, signed object URLs,
  category taxonomy, cart persistence, auth, or live K3d proof.
- `US-035 Flutter 360 Catalog Preview Activation` activates processed sprite
  previews on Flutter Home tab product cards after a card remains at least
  80% visible and scrolling is idle for three seconds. The preview uses the Go
  API `GET /catalog/products/{id}/sprite` route and the existing 24-frame
  sprite-sheet contract without adding category taxonomy, sorting controls,
  product detail, signed object URLs, device-tier GLB selection, cart
  persistence, auth, Flutter Bazel rules, live backend proof, or live device
  proof.
- `US-042 Customer Category Taxonomy And Sorting API` adds category slug/name
  arrays to product drafts and records, propagates category metadata into the
  derived Meilisearch product document, and exposes
  `GET /catalog/categories` plus
  `GET /catalog/categories/{slug}/products?sort=...` through the Go API
  gateway without adding Flutter Category tab UI, checkout, payments,
  authentication, authorization, inventory checks, backend cart APIs, signed
  object URLs, live backend proof, or live device proof.
- `US-043 Flutter Category Tab API Integration` connects the Flutter Category
  tab to those category routes, renders category selection, sort controls,
  category product pagination, incremental retry, scroll-to-top, and product
  detail navigation without adding checkout, payments, authentication,
  authorization, inventory checks, backend cart APIs, signed object URLs,
  Flutter Bazel rules, live backend proof, or live device proof.
- `US-044 Flutter Bazel Build And Test Boundary` adds a Bazel source and test
  boundary for the Flutter customer app. The Bazel test copies the app into a
  temporary directory and runs dependency resolution, formatting, analysis, and
  tests without adding checkout, payments, authentication, authorization,
  inventory checks, backend cart APIs, signed object URLs, production mobile
  release packaging, live backend proof, or live device proof.
- `US-049 Live Processed Product Catalog Smoke` completes live backend proof for
  the existing processed product flow. It creates a product through the admin
  API, uploads a source GLB, waits for worker processing and API completion,
  verifies completion-driven search synchronization, and proves catalog,
  search, category, detail, sprite, and tiered model routes through the Go API
  gateway without adding authentication, authorization, checkout, payments,
  order fulfillment, backend cart APIs, signed object URLs, product delete,
  direct platform access, new UI, or new customer contracts.
- `US-050 Live Flutter Customer Commerce Smoke` adds simulator proof for the
  existing Flutter customer flow against a live Go API gateway. It selects a
  completed processed product from the customer API, launches Flutter on an iOS
  simulator, and drives Home catalog browsing, search, Category tab browsing,
  Product Detail, high-tier model route metadata, material color selection, Add
  to cart, and Cart subtotal rendering without adding authentication,
  authorization, checkout, payments, order fulfillment, inventory checks,
  backend cart APIs, signed object URLs, direct platform access, new UI
  behavior, or new customer contracts.

## Phase 4: 3D Detail And Cart

Goal: adapt 3D delivery to device capability and support configurable products
in a local cart.

- Epic `E11`: Device-tier detection and 3D product viewer.
- Epic `E12`: Product configuration and related content.
- Epic `E13`: Persistent cart calculations.

Selected work:

- `US-036 Customer Product Detail And Tiered Model Access API` starts E11 with
  customer-facing `GET /catalog/products/{id}?tier=low|high` detail responses
  and `GET /catalog/products/{id}/model?tier=low|high` GLB streaming through
  the Go API gateway. The low tier serves completed optimized GLB output from
  `lumin-optimized-glb`; the high tier serves the completed product's source
  GLB from `lumin-source-glb`. The slice does not add Flutter device-tier
  detection, a Flutter 3D viewer, material color editing, related products,
  signed object URLs, cart persistence, auth, retry/outbox behavior, or live
  K3d proof.
- `US-037 Flutter Product Detail And Device Tier Integration` opens a Flutter
  product detail screen from Home catalog cards, derives a `low` or `high`
  device tier, and requests `GET /catalog/products/{id}?tier=low|high` through
  the existing Go API boundary. The screen renders loading, failure/retry, and
  ready states with seller-provided sections, mesh color configuration, and
  model/sprite route metadata without adding an interactive 3D viewer, material
  color editing, related products, signed object URLs, cart persistence, auth,
  Flutter Bazel rules, live backend proof, or live device proof.
- `US-038 Flutter Interactive 3D Viewer` renders an interactive model viewer
  on the Flutter product detail screen using the existing gateway `modelUrl`
  for the resolved device tier. The viewer enables rotate and zoom controls
  through the selected WebView-backed Flutter viewer bridge without adding
  material color editing, related products, signed object URLs, cart
  persistence, auth, Flutter Bazel rules, live backend proof, or live device
  proof.
- `US-039 Flutter Material Color Selection` lets the product detail screen
  initialize and update selected material colors from the existing
  `meshColorConfig` response. Allowed colors render as accessible touch swatches
  and selected colors stay in `ProductDetailCubit` state for later cart use
  without adding cart persistence, related products, signed object URLs, auth,
  Flutter Bazel rules, live backend proof, or live device proof.
- `US-040 Flutter Local Cart Persistence` lets customers add the selected
  Product Detail configuration to a locally persisted cart. The Cart tab renders
  stored product identity, selected mesh colors, quantity, and selection state
  with local quantity and selection updates without adding backend cart APIs,
  checkout, payments, inventory checks, pricing rules, signed object URLs, auth,
  Flutter Bazel rules, live backend proof, or live device proof.
- `US-041 Product Pricing Contract And Cart Totals` defines the first product
  display pricing object, persists it on product records, propagates it through
  search/catalog/detail API responses, snapshots it into local Flutter cart
  items, and renders selected subtotal and savings without adding checkout,
  payments, authentication, authorization, backend cart APIs, inventory checks,
  discount engines, Flutter Bazel rules, live backend proof, or live device
  proof.

## Deferred

- Authentication and authorization.
- Payments, checkout, and order fulfillment.
- Production hosting topology beyond the existing local K3d environment.

## Phase 5: Backend Cart And Checkout Foundation

Goal: move from local cart proof toward API-owned cart state before checkout,
payments, inventory, and account identity are selected.

- Epic `E14`: Backend cart contract and persistence.

Selected work:

- `US-051 Customer Backend Cart API Contract And Persistence Foundation` defines
  v1 cart contracts, stores anonymous server-side cart snapshots in PostgreSQL,
  and exposes `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}` through the
  Go API gateway. The API validates product existence and selected mesh colors
  against authoritative product rows, snapshots product name, category, price,
  processing status, and updated time, and recomputes cart totals without adding
  Flutter integration, checkout, payments, authentication, authorization,
  inventory checks, discount engines, tax, shipping, order fulfillment, signed
  object URLs, live backend proof, or live device proof.
- `US-052 Flutter Backend Cart API Integration` connects the Flutter customer
  cart repository to the existing Go API cart routes. The app stores the
  server cart id and latest item snapshot locally, loads `GET /cart/{id}` when
  possible, sends Product Detail and Cart tab mutations through `POST /cart` or
  `PUT /cart/{id}`, and shows Cart tab sync state without adding checkout,
  payments, authentication, authorization, inventory checks, tax, shipping,
  order fulfillment, signed object URLs, live backend proof, or live device
  proof.
- `US-053 Live Flutter Backend Cart Sync Smoke` proves the existing backend cart
  integration against a live Go API gateway and iOS simulator. It verifies
  `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}` with a completed
  catalog product, drives Product Detail Add to cart through Flutter, confirms
  the saved anonymous server cart id, and proves a fresh Cart tab load hydrates
  from the backend snapshot without adding checkout, payments, authentication,
  authorization, inventory checks, tax, shipping, order fulfillment, signed
  object URLs, direct platform access, or new cart contracts.
