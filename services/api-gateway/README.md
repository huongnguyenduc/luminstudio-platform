# API Gateway

The Go service at the center of Lumin Studio. It owns all business APIs and
relational state, coordinates MinIO object access, publishes and consumes NATS
events, and keeps the Meilisearch catalog index in sync. Browser and mobile
clients talk only to this gateway — never directly to PostgreSQL, MinIO, NATS,
or Meilisearch.

## Responsibilities

- **Product administration** — validate, persist, and serve the product catalog.
- **Asset coordination** — store source/processed GLB and sprite objects in
  MinIO and stream them back to clients.
- **Event orchestration** — publish `product.updated` and `3d.task.created`,
  and consume `3d.task.completed` to record processed assets.
- **Search synchronization** — project product changes into the Meilisearch
  `products` index through an asynchronous consumer.
- **Health & readiness** — expose liveness and platform-readiness probes for
  Kubernetes.

## HTTP API

| Area | Route | Description |
| --- | --- | --- |
| Health | `GET /healthz` · `GET /readyz` | Liveness and platform-readiness (PostgreSQL, MinIO, NATS, Meilisearch) |
| Admin | `GET/POST /admin/products` | List and create products |
| Admin | `GET/PUT /admin/products/{id}` | Read and full-replacement update |
| Admin | `POST /admin/products/{id}/source-glb` | Upload a source `.glb` and queue 3D processing |
| Catalog | `GET /catalog/products` · `GET /catalog/search?q=` | Meilisearch-backed catalog cards and search |
| Catalog | `GET /catalog/categories` · `GET /catalog/categories/{slug}/products?sort=` | Category taxonomy and sorting |
| Catalog | `GET /catalog/products/{id}?tier=low\|high` | Product detail, info sections, and asset routes |
| Catalog | `GET /catalog/products/{id}/model?tier=low\|high` | Stream optimized (low) or source (high) GLB |
| Catalog | `GET /catalog/products/{id}/sprite` | Stream the 360° sprite sheet |
| Cart | `POST /cart` · `GET/PUT /cart/{id}` | Anonymous cart snapshots with server-side validation and totals |

Product records carry a required display price and category metadata, which the
gateway persists in PostgreSQL, projects into Meilisearch (as filterable slugs
and sortable price amounts), and returns in catalog, search, and detail
responses. Cart mutations validate product ids and selected mesh colors against
authoritative product rows and recompute totals server-side.

**Out of scope (deferred):** authentication and authorization, checkout,
payments, inventory, orders, discount engines, signed object URLs, and
retry/outbox delivery semantics.

## Development

```bash
# Run native tests
go test ./...

# Build the OCI image (Linux amd64/arm64 targets via Bazel)
bazel build //services/api-gateway/...
```

## Verification

Each boundary ships with an executable verification script under `scripts/`.
Run any of them from the repository root:

```bash
bash scripts/verify-us-001.sh   # HTTP server foundation
bash scripts/verify-us-011.sh   # platform connectivity & readiness
bash scripts/verify-us-017.sh   # admin product API
bash scripts/verify-us-021.sh   # search synchronization
bash scripts/verify-us-029.sh   # customer catalog & search
bash scripts/verify-us-049.sh   # live processed-product smoke
bash scripts/verify-us-051.sh   # backend cart API
```

The complete story list and proof status is tracked via the Harness CLI:

```bash
scripts/bin/harness-cli query matrix
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for boundary rules and
[packages/shared-types](../../packages/shared-types/README.md) for the API and
event contracts this service implements.
