# US-050 Live Flutter Customer Commerce Smoke

## Status

in_progress

## Lane

normal

## Product Contract

The already implemented customer Flutter commerce flow must be proven on a
live simulator against a running Go API gateway. The smoke starts from a
completed, processed product exposed by the customer catalog API, then drives
Home catalog browsing, search, Category tab product browsing, Product Detail,
high-tier model route selection, material color selection, add-to-cart, and
Cart totals through the existing mobile UI.

This story adds live device proof for existing behavior. It does not add
authentication, authorization, checkout, payments, order fulfillment, inventory
checks, backend cart APIs, signed object URLs, new public API contracts, or
direct Flutter access to PostgreSQL, MinIO, NATS, or Meilisearch.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- A repeatable verifier selects a completed catalog product from
  `LUMIN_US050_API_BASE_URL` through the Go API gateway before launching the
  Flutter test.
- The verifier requires the selected product to have completed processing,
  category metadata, a sprite asset, a high-tier model route, and at least one
  configurable material color.
- A Flutter integration test runs on an iOS simulator with
  `LUMIN_API_BASE_URL` set to the live API gateway URL.
- The test proves Home catalog loading, Home search, Category tab category
  product loading, Product Detail navigation, high-tier model route metadata,
  material color selection, Add to cart, and Cart tab subtotal rendering.
- The test uses the existing Go API repository and local Flutter cart
  repository; it does not mock catalog/search/detail HTTP responses.
- The model viewer is replaced only inside the integration test with a stable
  lightweight Flutter widget so device smoke proof is not coupled to WebView
  GLB rendering.
- No checkout, payment, auth, inventory, backend cart, signed URL, direct
  platform-service access, or new customer contract behavior is added.

## Design Notes

- Commands: `LUMIN_US050_API_BASE_URL=http://127.0.0.1:8080 bash scripts/verify-us-050.sh`.
- Queries: catalog, search, categories, category products, and product detail
  are exercised through the existing Flutter API adapter.
- API: existing customer routes are used; no new HTTP routes are added.
- Tables: none.
- Domain rules: Cart state remains local to Flutter; PostgreSQL remains
  backend-authoritative for product data.
- UI surfaces: Home, Category, Product Detail, and Cart.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-050 --unit 1 --integration 1 --e2e 1 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | `flutter test` continues to pass for the mobile app. |
| Integration | Static verifier confirms the story, docs, integration test, runner wiring, and non-goals. |
| E2E | Flutter integration test drives the customer commerce flow against a live Go API base URL. |
| Platform | iOS simulator runs the Flutter app under test. |
| Release | Not required; this is local development simulator proof. |

## Harness Delta

None planned.

## Evidence

- `flutter pub get` resolved the new `integration_test` SDK dependency.
- `dart format --set-exit-if-changed lib test integration_test` passed.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 33 tests.
- `LUMIN_US050_API_BASE_URL=http://127.0.0.1:8080 bash scripts/verify-us-050.sh`
  reached the live API precondition and failed because no Go API was listening
  on `127.0.0.1:8080`; e2e/platform proof remains pending.
