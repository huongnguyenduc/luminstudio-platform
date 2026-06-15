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
`3d.task.created` for later worker processing. Customer search routes,
retry/outbox semantics, processing completion, and worker processing remain
deferred to later stories.

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
