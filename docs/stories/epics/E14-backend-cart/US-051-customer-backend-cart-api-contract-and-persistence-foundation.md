# US-051 Customer Backend Cart API Contract And Persistence Foundation

## Status

implemented

## Lane

normal

## Product Contract

The Go API exposes the first backend cart boundary for customer cart snapshots.
Customers can create an anonymous server-side cart with selected product
configurations, read that cart by server-generated cart id, and replace its
items. The API snapshots authoritative product name, price, category,
processing status, and product updated time from PostgreSQL while validating
selected mesh colors against the product's configured allowed colors.

This story does not add checkout, payments, authentication, authorization,
inventory checks, discount engines, tax, shipping, order fulfillment, seller
settlement, signed object URLs, Flutter API integration, live backend proof, or
live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Versioned v1 shared contracts define `CartId`, `CartUpsertRequest`,
  `CartItemSnapshot`, `CartTotals`, and `CartRecord`.
- PostgreSQL has a `carts` persistence foundation storing item snapshots,
  totals, and server-owned timestamps.
- The Go API exposes `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}`
  through the gateway.
- Cart create/update validates product ids, quantity bounds, duplicate product
  configuration entries, product existence, and selected colors against the
  authoritative product row.
- Cart totals are API-owned and recomputed from stored snapshots; mixed
  currency carts do not expose a single selected amount.
- No checkout, payment, auth, inventory, order, signed URL, direct platform, or
  Flutter behavior is added.

## Design Notes

- Commands: cart create and full replacement update are synchronous HTTP
  mutations without event publication.
- Queries: `GET /cart/{id}` reads the persisted anonymous cart snapshot from
  PostgreSQL.
- API: `POST /cart`, `GET /cart/{id}`, `PUT /cart/{id}`.
- Tables: `carts` with JSONB `items`, JSONB `totals`, server-owned timestamps,
  and v1 `cart_` id validation.
- Domain rules: PostgreSQL remains authoritative for product data; cart item
  requests provide only product id, selected colors, quantity, and selection
  state.
- UI surfaces: none in this slice.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-051 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go cart domain, store argument, handler, and route tests pass. |
| Integration | `go test ./...` in `services/api-gateway`, focused Bazel API/cart tests, shared contract build, migration build, and static verifier pass. |
| E2E | Not required; no live backend, checkout, payment, auth, or Flutter integration in this slice. |
| Platform | Not required; no K3d deployment or live service behavior changes in this slice. |
| Release | Deferred. |

## Harness Delta

Adds `scripts/verify-us-051.sh` and a Harness story row for the backend cart API
foundation.

## Evidence

- `bash scripts/verify-us-051.sh` passed.
- `scripts/bin/harness-cli story verify US-051` passed and recorded durable
  proof.
- Native Go proof: `go test ./...` passed in `services/api-gateway`.
- Bazel proof: shared contracts, API binary, migrations, `api_gateway_test`,
  and `internal/cart:cart_test` passed through the story verifier.
