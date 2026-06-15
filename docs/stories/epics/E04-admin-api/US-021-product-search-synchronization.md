# US-021 Product Search Synchronization

## Status

implemented

## Lane

normal

## Product Contract

The Go API runs a search-sync consumer for v1 `product.updated` events. When an
event is received, the consumer validates the event envelope, reads the
authoritative product record from PostgreSQL, and upserts one derived product
document into the Meilisearch `products` index. Admin product mutation requests
remain decoupled from Meilisearch availability because synchronization happens
through the event path.

This story does not add admin UI behavior, customer catalog/search HTTP routes,
mobile behavior, product delete workflows, MinIO uploads, worker processing,
retry/outbox semantics, dead-letter handling, authentication, authorization,
filtering, pagination, or live K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/api-gateway` has a search-sync handler that accepts v1
  `product.updated` event JSON, rejects malformed or wrong-type events, and
  requires product identity, correlation identity, and changed timestamp.
- The handler reads the product record from PostgreSQL-backed product storage
  before indexing, keeping PostgreSQL as the source of truth.
- The Meilisearch adapter upserts one derived product document to
  `/indexes/products/documents?primaryKey=id` using the configured
  `MEILISEARCH_URL` and `MEILISEARCH_API_KEY`.
- The runtime API gateway starts a NATS subscriber on the existing
  `lumin.product.updated` subject and queue group `search-sync`.
- Search sync errors are logged and do not add synchronous coupling to admin
  product mutation responses.
- Verification proves native Go tests, Bazel tests, API gateway build, search
  handler behavior, Meilisearch request shape, runtime wiring, docs updates,
  and story non-goals without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-021.sh`.
- Queries: search sync reads product records from PostgreSQL through the product
  store.
- API: none added.
- Tables: `products`.
- Indexes: Meilisearch `products`.
- Domain rules: the search document is derived from the product record returned
  by PostgreSQL after a `product.updated` event.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-021 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go and Bazel tests cover product.updated validation, product lookup, indexing failure propagation, document projection, and Meilisearch HTTP request shape. |
| Integration | Bazel builds and tests the API gateway target with search-sync runtime wiring. |
| E2E | Not required; no browser/mobile workflow exists in this story. |
| Platform | Not required; no live K3d NATS or Meilisearch proof is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-021.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel tests passed for `//services/api-gateway:api_gateway_test`,
  `//services/api-gateway/internal/product:product_test`, and
  `//services/api-gateway/internal/search:search_test`.
- Bazel built `//services/api-gateway:api-gateway`.
- Static verification found search-sync event handling, Meilisearch document
  upsert shape, NATS subscriber runtime wiring, docs updates, and story
  non-goals.
