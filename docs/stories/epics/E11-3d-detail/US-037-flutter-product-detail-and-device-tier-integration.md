# US-037 Flutter Product Detail And Device Tier Integration

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer app opens a product detail screen from Home catalog cards,
derives a device model tier inside the app, and requests product detail through
the Go API gateway with `GET /catalog/products/{id}?tier=low|high`.

The detail screen renders loading, failure/retry, and ready states with
seller-provided information sections, mesh color configuration, preview route
metadata, and the selected model route. Mobile clients continue to use only the
Go API boundary and do not access MinIO directly.

This story does not add an interactive Flutter 3D viewer, material color
editing, related products, signed object URLs, cart persistence,
authentication, authorization, Flutter Bazel rules, live backend proof, or live
device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- Tapping a Home catalog product pushes a product detail screen without losing
  Home tab navigation state.
- The Flutter app derives a `low` or `high` device tier before requesting
  product detail.
- The repository requests `GET /catalog/products/{id}?tier=low|high` through
  the existing Go API base URL.
- Product detail DTO parsing rejects malformed response bodies.
- The detail screen renders loading, failure/retry, and ready states.
- Ready state includes product name, description, dynamic information sections,
  mesh color configuration, selected model tier, model route, and optional
  sprite route.
- The implementation keeps direct PostgreSQL, MinIO, NATS, and Meilisearch
  access out of Flutter.

## Design Notes

- Commands: none added.
- Queries: product detail is a customer query through the API gateway.
- API: `GET /catalog/products/{id}?tier=low|high`.
- Tables: none.
- Domain rules: device tier is represented as `low` or `high`; product detail
  can only be requested through `CatalogRepository`.
- UI surfaces: Home catalog product tiles and a new product detail screen.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-037 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart tests cover product detail DTO parsing, tier query construction, malformed body rejection, and detail Cubit failure/retry behavior. |
| Integration | Flutter widget tests cover tapping a catalog product, derived tier usage, loading/failure/ready detail states, and tab navigation retention. |
| E2E | Not required; no live backend or device proof in this slice. |
| Platform | Not required; Flutter Bazel rules and live device proof remain deferred. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `dart format --set-exit-if-changed lib test` passed for
  `apps/mobile-flutter`.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 22 tests.
- `bash scripts/verify-us-037.sh` passed.
