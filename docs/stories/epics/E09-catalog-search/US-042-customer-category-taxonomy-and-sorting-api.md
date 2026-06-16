# US-042 Customer Category Taxonomy And Sorting API

## Status

implemented

## Lane

normal

## Product Contract

Product drafts and records may include up to eight customer-facing categories,
each with a stable slug and display name. The Go API persists categories on the
authoritative product row, propagates them into the derived Meilisearch product
document, returns them from catalog and product-detail responses, and exposes
category catalog routes through the API gateway.

Customers can list available categories with `GET /catalog/categories` and load
one category's products with
`GET /catalog/categories/{slug}/products?sort=newest|price_asc|price_desc|name_asc&limit=...&offset=...`.
The category product response reuses the existing catalog pagination envelope
and includes the selected `categorySlug` and `sort` metadata.

This story does not add Flutter Category tab UI, checkout, payments,
authentication, authorization, inventory checks, backend cart APIs, signed
object URLs, live backend proof, or live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`
- `docs/product/admin-and-processing.md`

## Acceptance Criteria

- Shared v1 product contracts define `ProductCategory`, category arrays on
  product draft, product record, catalog item, and product detail responses,
  plus the category-list response shape.
- Go product validation accepts valid category slug/name pairs and rejects bad
  slugs, duplicate slugs, and oversized category lists.
- PostgreSQL product storage persists and returns product categories through
  admin create, update, read, queue, and completion paths.
- Search sync indexes categories, category slugs, and a sortable price amount
  into Meilisearch, and configures the index for category filtering and sorting.
- The API exposes `GET /catalog/categories` through the Go gateway.
- The API exposes `GET /catalog/categories/{slug}/products` with category
  filtering, pagination, and the supported sort values.
- Customer catalog and detail responses include category metadata without
  leaking index-only fields.
- Verification proves Go tests, Bazel API/search/product tests, shared
  contract build, migration/static checks, and non-goals.

## Design Notes

- Commands: admin product create/update can carry optional `categories`.
- Queries: category list and category-product queries read from the derived
  Meilisearch index behind the API gateway.
- API: `GET /catalog/categories` and
  `GET /catalog/categories/{slug}/products` are customer-facing JSON routes.
- Tables: `products.categories` JSONB stores the v1 category array.
- Domain rules: category slugs use the v1 slug contract; category names are
  1-80 characters; product category lists are capped at eight entries.
- UI surfaces: none in this slice; Flutter Category tab wiring remains later.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-042 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go tests cover category validation, storage args, route parsing, Meilisearch request shape, and index document shape. |
| Integration | Static verifier confirms schema, migration, route wiring, docs, non-goals, and Bazel API/search/product/shared-contract targets. |
| E2E | Not required; no live backend or Flutter UI behavior in this slice. |
| Platform | Not required; no K3d deployment behavior changes. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `go test ./...` passed for `services/api-gateway`.
- `bash scripts/verify-us-042.sh` passed, including native Go tests,
  `bazelisk build //packages/shared-types:contracts_v1 //services/api-gateway:api-gateway //services/api-gateway/migrations:migrations`,
  and Bazel tests for `api_gateway_test`, `product_test`, and `search_test`.
- `scripts/bin/harness-cli story verify US-042` passed.
