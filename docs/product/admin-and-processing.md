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

Authentication, authorization, product update/delete workflows, source GLB
uploads, event publication, search synchronization, and worker processing
remain deferred.

## Processing Pipeline

1. The API publishes `3d.task.created` with a stable task and product identity.
2. The Rust worker downloads the source GLB from MinIO.
3. A reviewed C++ FFI wrapper invokes meshoptimizer to create a low-poly GLB.
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

- FFI ownership and allocation rules must be explicit and leak-tested.
- Duplicate events must not corrupt product state or create conflicting output
  references.
- Search and processing failures must be observable without blocking unrelated
  API traffic.
