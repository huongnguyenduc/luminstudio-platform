# Admin And 3D Processing

## Product Management

Administrators can create and edit products. A product may include dynamic,
collapsible information sections appropriate to its product type.

When a product mutation succeeds, the API publishes `product.updated`. A Go
search-sync handler consumes that event and updates Meilisearch without making
the admin request depend on search availability.

## Source Asset Intake

- The administrator uploads one high-quality `.glb` source through the Go API.
- The API stores the source object in MinIO and creates a processing task.
- Configurable mesh data identifies each mutable `mesh_id`, its default color,
  and its allowed colors.
- The admin surface initially supports entering this configuration as JSON.
- Mesh configuration is parsed and validated before persistence or event
  publication.

Example shape:

```json
{
  "mesh_body": {
    "default": "#FFFFFF",
    "allowed": ["#000000", "#FF0000"]
  }
}
```

The shared contract source now starts with JSON Schema files under
`packages/shared-types/contracts/v1`. These schemas define the initial product
draft and record shapes, object references for source GLB, optimized GLB, and
360-degree sprite assets, and the mesh color configuration shape that later API
stories must parse before persistence or event publication.

The Go API now has an initial product persistence foundation under
`services/api-gateway/internal/product` plus a PostgreSQL `products` schema under
`services/api-gateway/migrations`. The foundation validates product drafts,
dynamic information sections, mesh color configuration, source asset
references, and processing status before later stories expose runtime HTTP
routes or event publication.

The Go API now exposes the first runtime product administration route:
`POST /admin/products`. The endpoint accepts the v1 product draft JSON shape,
validates the draft at the HTTP boundary, creates the server-side product
identity, persists through the product store, and returns the created product
record.

The Go API also exposes product read routes for the admin surface:
`GET /admin/products` returns persisted product records and
`GET /admin/products/{id}` returns one persisted product record by v1 product
identity. These read routes use PostgreSQL as the source of truth and do not
read from Meilisearch, MinIO, NATS, or the worker.

The Go API also exposes full-replacement product updates through
`PUT /admin/products/{id}`. The endpoint accepts the same v1 product draft shape
as creation, validates the path identity before persistence access, updates the
PostgreSQL product row, and preserves server-owned identity, creation time,
processing status, and processed asset references.

The Go API now publishes a v1 `product.updated` event after successful
`POST /admin/products` and `PUT /admin/products/{id}` persistence. The event is
published through NATS with a stable envelope, correlation identity, product
identity, and changed timestamp so a later search-sync handler can update
Meilisearch asynchronously.

The Go API now runs the first search-sync consumer for `product.updated`. The
consumer validates the event envelope, reads the authoritative product record
from PostgreSQL, and upserts a derived document into the Meilisearch `products`
index. Search sync failures are logged and do not add synchronous Meilisearch
coupling to admin product mutation responses.

The Go API now exposes administrator source GLB upload through
`POST /admin/products/{id}/source-glb`. The endpoint accepts a multipart
`source` `.glb` file for an existing product with valid mesh color
configuration, stores the object in MinIO under
`lumin-source-glb/products/{productId}/source.glb`, updates PostgreSQL with the
source asset reference and `queued` processing status, publishes
`product.updated`, and publishes `3d.task.created` for later worker
processing.

The Rust worker parses and validates v1 `3d.task.created` events, exposes the
`lumin.3d.task.created` subscription boundary, and requests the referenced
source GLB object from a source asset reader. Later worker stories compose this
intake with mesh optimization, 360-degree rendering, processed asset upload,
and `3d.task.completed` publication.

The worker now has the first mesh optimization implementation through the
upstream-recommended Rust `meshopt` crate. Supported GLB 2.0 assets with one
embedded buffer, indexed triangle primitives, float32 `POSITION` accessors, and
tightly packed u16/u32 index buffer views can be simplified into a smaller valid
GLB while preserving scene, node, mesh, and material metadata. Unsupported or
ambiguous buffer layouts are rejected before processing. The deterministic
output naming helper follows `[productId]_low.glb`; storage upload and runtime
task wiring remain deferred.

The worker uses Blender's headless CLI and Python API as the selected
360-degree renderer. The initial deterministic contract uses EEVEE, a fixed
camera orbit and lighting setup, 24 frames at 160-by-160 pixels, and a 6-by-4
JPEG sprite sheet named `[productId]_360_sprite.jpg`. Determinism is scoped to
the same Blender build, platform, script, input, and render configuration.
The runtime worker now composes source download, mesh optimization, Blender
rendering, and uploads processed assets to MinIO. It writes optimized GLBs to
`lumin-optimized-glb`, writes sprite sheets to `lumin-360-sprites`, and
publishes a v1 `3d.task.completed` event only after both uploads succeed.
The worker now also has a local development worker image and K3d Deployment so
the live development platform can run the processing loop through NATS and
MinIO. Production image hardening and retry/dead-letter behavior remain
deferred.

The Go API now consumes valid v1 `3d.task.completed` events through a dedicated
NATS queue group. It strictly validates the completion envelope and processed
object references, then atomically stores the optimized GLB and sprite assets
and marks the authoritative PostgreSQL product record as `completed`. The live
development smoke now proves that one uploaded GLB can move from `queued` to
`completed` through the API, NATS, worker, MinIO, and completion consumer
boundaries. Retry/outbox semantics, failure events, production image hardening,
and dead-letter behavior remain deferred.

The Go API now exposes the first customer-facing catalog/search boundary:
`GET /catalog/products` and `GET /catalog/search?q=...` query the derived
Meilisearch `products` index from inside the API gateway and return customer
catalog item fields plus optional sprite asset references. Clients remain behind
the API boundary and do not connect directly to Meilisearch, PostgreSQL, MinIO,
or NATS. The API also exposes `GET /catalog/products/{id}/sprite` to stream the
completed product's 360-degree sprite JPEG from MinIO after checking the
authoritative product row.
The API now also exposes customer product detail through
`GET /catalog/products/{id}?tier=low|high` and GLB model bytes through
`GET /catalog/products/{id}/model?tier=low|high`. Both routes read the
authoritative product row first, require completed processing and matching
object references, and keep source and optimized GLB access behind the API
gateway rather than exposing direct MinIO URLs.
Product drafts and records now include a required display price with integer
cents, an uppercase three-letter currency code, and an optional compare-at
amount. The Go API persists this price on the authoritative product row,
propagates it through `product.updated` search synchronization, and returns it
from customer catalog and product-detail responses. Checkout, payments,
authentication, authorization, backend cart APIs, inventory checks, discount
engines, tax, shipping, and seller settlement remain deferred.
`US-042` adds customer-facing categories to product drafts and records with
stable slugs and display names. The API persists those category arrays on the
authoritative product row, propagates category metadata and filter slugs into
Meilisearch, exposes `GET /catalog/categories`, and exposes
`GET /catalog/categories/{slug}/products` with pagination plus `newest`,
`price_asc`, `price_desc`, and `name_asc` sort values. The Flutter Category tab
now consumes those routes through the Go API gateway with category selection,
sorting, paginated product results, incremental retry, scroll-to-top, and
product detail navigation. Live backend proof remains deferred.

Authentication, authorization, product delete workflows, signed object URLs,
retry/outbox semantics, and dead-letter handling remain deferred.

## Processing Pipeline

1. The API publishes `3d.task.created` with a stable task and product identity.
2. The Rust worker downloads the source GLB from MinIO.
3. The Rust worker invokes the pinned `meshopt` crate to create a low-poly GLB.
4. A headless renderer creates a 360-degree sprite asset.
5. The worker uploads processed assets to MinIO.
6. The worker publishes `3d.task.completed` with output object references.
7. The Go API consumes completion and updates relational product state.

## Output Contract

The initial naming convention from the source spec is:

- `[id]_low.glb`
- `[id]_360_sprite.jpg`

Versioned event schema sources exist for `product.updated`, `3d.task.created`,
and `3d.task.completed`. Object key policy beyond the initial source-spec naming
convention, retry semantics, idempotency, failure events, and dead-letter
handling remain open decisions for later Phase 2 implementation stories.

## Quality Requirements

- Unsupported GLB layouts must fail before emitting a partial optimized asset.
- Duplicate events must not corrupt product state or create conflicting output
  references.
- Search and processing failures must be observable without blocking unrelated
  API traffic.
