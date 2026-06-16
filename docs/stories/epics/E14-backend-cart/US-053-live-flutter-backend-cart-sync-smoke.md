# US-053 Live Flutter Backend Cart Sync Smoke

## Status

implemented

## Lane

normal

## Product Contract

The existing Flutter backend cart integration now has live simulator proof
against a running Go API gateway. The flow adds a completed processed product
to cart from Product Detail, stores the anonymous server cart id in local
preferences, verifies the server cart snapshot through `GET /cart/{id}`, sends
an update through the Cart tab, and proves a fresh app load hydrates the cart
from the backend record.

This story does not add checkout, payments, authentication, authorization,
inventory checks, tax, shipping, order fulfillment, seller settlement, signed
object URLs, new cart contracts, or direct PostgreSQL, MinIO, NATS, or
Meilisearch access from Flutter.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The verifier requires a live Go API base URL and chooses a completed catalog
  product with mesh color configuration from the customer API.
- The verifier proves live `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}`
  behavior with curl before launching Flutter.
- The iOS simulator test drives Product Detail Add to cart through the Flutter
  UI and observes a saved anonymous server cart id.
- The simulator test reads the saved server cart through the Go API and
  verifies product id, selected mesh color, quantity, selected state, and
  totals.
- The Cart tab quantity update is reflected in the server cart record.
- Restarting the app with the saved cart id hydrates the Cart tab from the
  backend cart snapshot.
- No checkout, payment, auth, inventory, signed URL, order, or direct platform
  service access is added.

## Design Notes

- Commands: Product Detail Add to cart and Cart tab quantity updates remain the
  only Flutter cart mutations exercised.
- Queries: Startup cart load uses the saved server cart id and reads
  `GET /cart/{id}`.
- API: Reuses `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}` from
  `US-051`; no new backend route is introduced.
- Local persistence: `SharedPreferencesAsync` keeps the anonymous server cart
  id and latest item snapshot as established by `US-052`.
- UI surfaces: Existing Product Detail and Cart tab surfaces are tested without
  visual redesign.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-053 --unit 1 --integration 1 --e2e 1 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Existing Flutter cart data and widget tests continue to pass. |
| Integration | Static verifier, `flutter analyze`, `flutter test`, and live cart API curl checks pass. |
| E2E | Simulator integration test drives Product Detail, backend cart create/update, and Cart hydration. |
| Platform | iOS simulator proof runs against a live Go API gateway. |
| Release | Deferred. |

## Harness Delta

Adds `scripts/verify-us-053.sh` and a Harness story row for live Flutter
backend cart sync proof.

## Evidence

- `dart format --set-exit-if-changed lib test integration_test` passed in
  `apps/mobile-flutter`.
- `flutter analyze` passed in `apps/mobile-flutter`.
- `flutter test` passed in `apps/mobile-flutter` with 38 tests.
- `LUMIN_US053_API_BASE_URL=http://127.0.0.1:22071 bash scripts/verify-us-053.sh`
  passed on 2026-06-16 against a temporary K3d live API and iOS simulator for
  product `prod_K3l8RIu62UeF7djlMo6-xjTn`.
