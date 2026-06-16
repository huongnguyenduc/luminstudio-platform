# API Gateway

Go service responsible for business APIs, PostgreSQL state, MinIO access
coordination, NATS publication/consumption, and Meilisearch synchronization.

Phase 1 currently provides a standard-library HTTP server with independent
`GET /healthz` liveness and `GET /readyz` platform-readiness endpoints plus
Bazel OCI image targets for Linux amd64 and arm64. Readiness checks PostgreSQL,
MinIO, NATS, and Meilisearch without introducing product schema, buckets,
indexes, event contracts, or product endpoints.

Phase 2 now has a product persistence foundation with typed product draft and
record validation in `internal/product` plus the initial PostgreSQL `products`
schema in `migrations`. The first runtime product administration route is
`POST /admin/products`, which validates a v1 product draft, generates the
server-side product identity, persists through the product store, and returns a
created product record. Admin read routes now expose `GET /admin/products` and
`GET /admin/products/{id}` from PostgreSQL-backed product storage. Admin update
behavior now exposes `PUT /admin/products/{id}` as a full-replacement update
that preserves server-owned product fields. Product create and update mutations
now publish v1 `product.updated` events through NATS for later asynchronous
search synchronization. The API gateway now also runs a search-sync consumer
that handles `product.updated`, reads product records from PostgreSQL, and
upserts derived documents into the Meilisearch `products` index. Source GLB
upload is now exposed at `POST /admin/products/{id}/source-glb`; the handler
stores the source object in MinIO, updates the product source asset and queued
processing status, publishes `product.updated`, and publishes
`3d.task.created` for worker processing. The API also consumes valid
`3d.task.completed` events, atomically stores both processed asset references,
and marks the product processing state as completed. Customer-facing
`GET /catalog/products` and `GET /catalog/search?q=...` routes now query the
derived Meilisearch `products` index through the API gateway and return v1
catalog card response shapes. The API also streams completed customer
360-degree sprite JPEGs from MinIO through
`GET /catalog/products/{id}/sprite`, after checking the authoritative product
row. Product detail now uses `GET /catalog/products/{id}?tier=low|high` to
return seller-provided information sections, mesh color configuration, and
gateway asset routes. Model bytes are streamed through
`GET /catalog/products/{id}/model?tier=low|high`, with low tier reading the
optimized GLB and high tier reading the source GLB after the product row is
completed. Retry/outbox semantics remain deferred.
Product drafts and records now include a required display price; the API
persists it on PostgreSQL product rows, propagates it into Meilisearch product
documents, and returns it from customer catalog/search/detail responses. This
does not add checkout, payments, authentication, authorization, backend cart
APIs, inventory checks, or discount engines.
`US-042` adds category slug/name pairs to product drafts and records. The API
persists them on PostgreSQL product rows, propagates category metadata,
filterable category slugs, and sortable price amounts into Meilisearch, and
exposes `GET /catalog/categories` plus
`GET /catalog/categories/{slug}/products?sort=...` through the gateway without
adding Flutter Category tab UI, checkout, payments, auth, inventory, or backend
cart APIs.
The API also republishes `product.updated` after processing completion so the
derived Meilisearch catalog document can reflect completed processing state and
sprite metadata. `US-049` proves one live processed product through admin
creation, source upload, worker completion, catalog/search/category queries,
product detail, sprite streaming, and low/high model streaming behind the API
gateway.

Run native tests:

```bash
go test ./...
```

Run the complete story verification from the repository root:

```bash
bash scripts/verify-us-001.sh
```

Verify OCI packaging and the K3d deployment from the repository root:

```bash
bash scripts/verify-us-010.sh
```

Verify platform connectivity and readiness behavior from the repository root:

```bash
bash scripts/verify-us-011.sh
```

Verify the product persistence foundation from the repository root:

```bash
bash scripts/verify-us-016.sh
```

Verify the admin product HTTP API from the repository root:

```bash
bash scripts/verify-us-017.sh
```

Verify the admin product read HTTP API from the repository root:

```bash
bash scripts/verify-us-018.sh
```

Verify the admin product update HTTP API from the repository root:

```bash
bash scripts/verify-us-019.sh
```

Verify admin product mutation event publication from the repository root:

```bash
bash scripts/verify-us-020.sh
```

Verify product search synchronization from the repository root:

```bash
bash scripts/verify-us-021.sh
```

Verify admin source GLB upload and task event publication from the repository
root:

```bash
bash scripts/verify-us-022.sh
```

Verify customer catalog/search API routes from the repository root:

```bash
bash scripts/verify-us-029.sh
```

Verify customer sprite preview asset access from the repository root:

```bash
bash scripts/verify-us-034.sh
```

Verify customer product detail and tiered model access from the repository
root:

```bash
bash scripts/verify-us-036.sh
```

Verify product pricing contract and cart totals from the repository root:

```bash
bash scripts/verify-us-041.sh
```

Verify customer category taxonomy and sorting API from the repository root:

```bash
bash scripts/verify-us-042.sh
```

Verify the live processed product catalog smoke from the repository root:

```bash
bash scripts/verify-us-049.sh
```
