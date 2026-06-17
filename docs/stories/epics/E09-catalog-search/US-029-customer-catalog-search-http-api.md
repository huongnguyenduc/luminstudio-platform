# US-029 Customer Catalog Search HTTP API

## Status

implemented

## Lane

normal

## Product Contract

The Go API exposes customer-facing catalog and search HTTP routes backed by the
derived Meilisearch `products` index. Mobile and browser clients request catalog
cards through the API boundary instead of connecting directly to Meilisearch,
PostgreSQL, MinIO, or NATS.

`GET /catalog/products` returns a paginated catalog response using an empty
Meilisearch query. `GET /catalog/search?q=...` requires a non-empty query and
uses the same response shape. Responses expose customer-safe product card
fields, processing status, and the 360-degree sprite asset reference when the
processed product document has one.

This story does not add Flutter UI, browser UI, category taxonomy, sorting,
signed object URLs, product detail, device-tier GLB selection, cart behavior,
authentication, authorization, retry/outbox semantics, failure events,
dead-letter handling, or live K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `packages/shared-types/contracts/v1/product.schema.json` defines the v1
  customer catalog item and catalog search response shapes.
- Product search documents include `spriteAsset` so catalog responses can expose
  the processed 360-degree preview reference after completion.
- `services/api-gateway` exposes `GET /catalog/products` and
  `GET /catalog/search?q=...` through the Go API gateway.
- The catalog/search handler validates `q`, `limit`, and `offset` before
  querying Meilisearch.
- The Meilisearch adapter queries `/indexes/products/search` with `q`, `limit`,
  and `offset`, using the configured `MEILISEARCH_URL` and
  `MEILISEARCH_API_KEY`.
- Customer responses contain product identity, name, slug, description,
  processing status, optional sprite asset, update time, total, limit, offset,
  and optional query; they do not expose admin-only mesh configuration, source
  asset references, or index-only text.
- Verification proves native Go tests, Bazel tests, API gateway build,
  contract schema parseability, runtime route wiring, docs updates, and story
  non-goals without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-029.sh`.
- Queries: API gateway queries the Meilisearch `products` index through a
  package-local adapter.
- API: `GET /catalog/products`, `GET /catalog/search?q=...`.
- Tables: none added.
- Indexes: Meilisearch `products`, populated by existing `product.updated`
  search synchronization.
- Domain rules: PostgreSQL remains authoritative for admin mutations; customer
  catalog/search is served from the derived search document.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-029 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go tests cover route validation, customer-safe response projection, Meilisearch request shape, and runtime route exposure. |
| Integration | Bazel tests the API gateway and search package, and builds the API gateway binary. |
| E2E | Not required; no Flutter/browser workflow exists in this story. |
| Platform | Not required; no live K3d Meilisearch proof is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-029.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel tests passed for `//services/api-gateway:api_gateway_test` and
  `//services/api-gateway/internal/search:search_test`.
- Bazel built `//services/api-gateway:api-gateway` and
  `//packages/shared-types:contracts_v1`.
- Static verification found v1 catalog response contracts, route wiring,
  Meilisearch search request shape, customer-safe response projection, docs
  updates, and story non-goals.
