# US-040 Flutter Local Cart Persistence

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer app lets customers add the currently selected product
configuration from Product Detail into a locally persisted cart. The cart stores
product identity, selected mesh colors, quantity, and selection state on the
device, then renders the Cart tab from that local state.

The Cart tab supports empty, loading, failure, and ready states. Ready state
shows quantity controls and selected mesh colors for each cart item. The
quantity and selection state persist immediately after customer interaction.

This story does not add backend cart APIs, checkout, payments, inventory
checks, pricing precision, currency, discount rules, authentication,
authorization, signed object URLs, Flutter Bazel rules, live backend proof, or
live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- Product Detail exposes an accessible Add to cart action after product detail
  and selected mesh colors are ready.
- Adding to cart persists product identity, selected mesh colors, quantity, and
  selection state through local Flutter storage.
- Adding the same product with the same selected colors increments quantity
  instead of duplicating an item.
- The Cart tab renders an empty state when no cart items are stored.
- The Cart tab renders stored cart items with selected mesh colors and quantity
  controls.
- Quantity and selection changes persist through the cart repository.
- Widget tests cover add-to-cart, selected color persistence, quantity changes,
  and Cart tab ready state.
- Verification captures a mobile-size Cart tab screenshot with a configured
  product in the cart.
- The implementation keeps direct PostgreSQL, MinIO, NATS, and Meilisearch
  access out of Flutter.

## Design Notes

- Commands: Product Detail Add to cart and Cart tab quantity/selection updates.
- Queries: Cart tab reads local cart state only; no backend query is added.
- API: none.
- Tables: none.
- Domain rules: Cart item identity is product id plus selected mesh color map.
- UI surfaces: Product Detail and Cart tab.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-040 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart analysis and widget tests cover cart add, persistence, selection, and quantity behavior. |
| Integration | Static verifier confirms cart repository, Product Detail wiring, Cart tab UI, docs, non-goals, and mobile screenshot capture. |
| E2E | Not required; no live backend or live device proof in this slice. |
| Platform | Not required; Flutter Bazel rules and live device proof remain deferred. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `flutter pub get` resolved dependencies for `apps/mobile-flutter`.
- `dart format --set-exit-if-changed lib test` passed for
  `apps/mobile-flutter`.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 28 tests.
- `bash scripts/verify-us-040.sh` passed.
- Mobile viewport Cart tab capture saved at
  `reports/us-040/cart-local-persistence.png`; the capture shows the local Cart
  tab with a configured `prod_1` item, selected `mesh_body: #0F172A`, quantity
  controls, and selected-item summary.
