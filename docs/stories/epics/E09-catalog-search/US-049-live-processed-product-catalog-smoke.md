# US-049 Live Processed Product Catalog Smoke

## Status

implemented

## Lane

normal

## Product Contract

The existing backend commerce and 3D pipeline must be proven as one live
customer-facing flow. A product created through the admin API, uploaded with a
source `.glb`, processed by the worker, completed by the API, and synchronized
to Meilisearch must become visible through the customer catalog, search,
category, product detail, sprite, and tiered model API routes.

This story completes proof and synchronization for already implemented
behavior. It does not add authentication, authorization, checkout, payments,
order fulfillment, backend cart APIs, signed object URLs, product delete
workflows, new UI, or direct client access to PostgreSQL, MinIO, NATS, or
Meilisearch.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The API republishes `product.updated` after valid `3d.task.completed`
  consumption so the derived catalog index receives completed processing state
  and processed sprite metadata.
- A repeatable verifier creates an isolated K3d cluster, imports API and worker
  images, applies the dev overlay, runs the product migration, creates a priced
  categorized product through `POST /admin/products`, uploads
  `resources/pet_tag.glb`, and waits for the admin product record to become
  `completed`.
- The verifier waits until the customer-facing `GET /catalog/products` and
  `GET /catalog/search?q=...` routes return the completed product with display
  price, category metadata, and sprite asset metadata from Meilisearch.
- The verifier proves `GET /catalog/categories` and
  `GET /catalog/categories/{slug}/products?sort=price_asc` expose the product's
  category and completed catalog item.
- The verifier proves `GET /catalog/products/{id}?tier=low|high`,
  `GET /catalog/products/{id}/sprite`, and
  `GET /catalog/products/{id}/model?tier=low|high` return the completed
  product detail, JPEG sprite bytes, optimized low-tier GLB bytes, and source
  high-tier GLB bytes through the API gateway.
- The flow remains behind the Go API gateway and does not introduce auth,
  checkout, payments, order fulfillment, backend cart APIs, signed URLs, product
  delete workflows, direct platform access, new UI, or new product contracts.

## Design Notes

- Commands: `bash scripts/verify-us-049.sh`.
- Queries: customer catalog, search, category, detail, sprite, and model routes
  are exercised through the API gateway.
- API: existing admin and customer routes are used; no new HTTP routes are
  added.
- Tables: existing `products` migration is applied in the isolated verifier.
- Domain rules: PostgreSQL remains authoritative; Meilisearch is refreshed from
  `product.updated`; processed assets are streamed through the API gateway.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-049 --unit 1 --integration 1 --e2e 1 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go tests cover completion-triggered `product.updated` publication. |
| Integration | Bazel API/search/product/processing tests and API binary build pass. |
| E2E | Isolated live smoke proves admin processing to customer catalog/detail/asset routes through the API gateway. |
| Platform | Isolated K3d cluster runs PostgreSQL, MinIO, NATS, Meilisearch, API, and worker for the smoke. |
| Release | Not required; this is local development proof. |

## Harness Delta

None planned.

## Evidence

- `go test ./...` from `services/api-gateway` passed.
- `bash scripts/verify-us-049.sh` passed on 2026-06-16 for
  `prod_VbQuyLWGM_ZklVtwIbt18bw3`. The verifier also ran Bazel API tests and
  build targets, `cargo test -p worker-3d`, `bazelisk test //services/worker-3d/...`,
  and an isolated K3d live smoke from admin source upload through worker
  processing to customer catalog, search, category, detail, sprite, and low/high
  model routes.
- `scripts/bin/harness-cli story verify US-049` passed on 2026-06-16 for
  `prod_wg0aeXfL7nH-Nv32kMzzFU65`.
