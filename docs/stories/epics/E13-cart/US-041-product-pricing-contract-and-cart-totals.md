# US-041 Product Pricing Contract And Cart Totals

## Status

implemented

## Lane

normal

## Product Contract

Product drafts and records include a required display price with integer cents,
an uppercase three-letter currency code, and an optional compare-at amount. The
Go API persists that price on the authoritative product row, propagates it into
the derived Meilisearch product document, and returns it from customer catalog
and product-detail responses.

The Flutter customer app parses the v1 price contract, displays product detail
price, snapshots price data into locally persisted cart items, and recalculates
selected cart subtotal and savings when quantity or selection changes. Cart
totals are shown only when selected items share one currency.

This story does not add checkout, payments, authentication, authorization,
backend cart APIs, inventory checks, discount engines, tax, shipping, seller
settlement, signed object URLs, Flutter Bazel rules, live backend proof, or
live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`
- `docs/product/admin-and-processing.md`

## Acceptance Criteria

- Shared v1 product contracts define `ProductPrice` and require `price` on
  product draft, product record, catalog item, and product detail responses.
- Go product validation rejects missing, zero, malformed-currency, and invalid
  compare-at prices.
- PostgreSQL product storage persists `price` and returns it through admin
  create, update, read, queue, and completion paths.
- Search sync indexes product price and customer catalog/detail responses return
  price through the Go API gateway.
- Flutter catalog and product-detail DTOs parse price from the API contract.
- Product Detail displays the selected product price near the seller-provided
  information.
- Adding to cart snapshots product name and price into local cart storage.
- The Cart tab shows selected subtotal and savings, and updates both when
  quantity or selection changes.
- Widget tests cover price parsing, add-to-cart price snapshot, subtotal, and
  savings behavior.
- Verification captures the mobile Cart tab screenshot with a priced configured
  product in the cart.
- No checkout, payment, auth, inventory, or backend cart API behavior is added.

## Design Notes

- Commands: admin product create/update carry required `price`; Flutter add to
  cart snapshots product price into local storage.
- Queries: catalog/search/detail responses include price from API-owned product
  state or search documents.
- API: existing admin, catalog, and product-detail endpoints are extended with
  `price`; no checkout or payment endpoints are added.
- Tables: `products.price` JSONB stores the v1 display pricing object.
- Domain rules: amount is integer cents greater than zero; currency is an
  uppercase three-letter code; compare-at amount must be greater than amount.
- UI surfaces: Product Detail price text and Cart summary subtotal/savings.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-041 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go and Flutter tests cover pricing validation, DTO parsing, cart price snapshot, subtotal, and savings. |
| Integration | Static verifier confirms schema, migration, API/search propagation, Flutter persistence/UI, docs, non-goals, and screenshot capture. |
| E2E | Not required; no live backend, checkout, payment, auth, or live device proof in this slice. |
| Platform | Not required; no platform deployment behavior changes. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `go test ./...` passed for `services/api-gateway`.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test test/us040_capture_test.dart --update-goldens` passed and
  refreshed `reports/us-040/cart-local-persistence.png`.
- `flutter test` passed for `apps/mobile-flutter` with 28 tests.
