# US-038 Flutter Interactive 3D Viewer

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer product detail screen renders an interactive 3D viewer for
the completed product model returned by the Go API gateway. The viewer uses the
existing `modelUrl` from `GET /catalog/products/{id}?tier=low|high`, keeps the
selected low/high tier behavior from `US-037`, and supports touch/mouse camera
rotation plus zoom through the selected Flutter viewer bridge.

Mobile clients continue to request model assets only through the Go API
gateway. The app does not receive direct MinIO URLs, credentials, signed object
URLs, or direct storage access.

This story does not add material color editing, related products, category
taxonomy, sorting controls, cart persistence, authentication, authorization,
Flutter Bazel rules, live backend proof, or live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- The Product Detail ready state includes an interactive 3D viewer panel above
  product copy.
- The viewer source is the gateway `modelUrl` returned by the product detail
  response for the resolved device tier.
- Runtime viewer configuration enables camera controls and zoom.
- Product detail widget tests can inject a lightweight viewer builder instead
  of initializing a WebView-backed viewer.
- Missing `modelUrl` renders a stable unavailable state instead of crashing.
- The implementation keeps direct PostgreSQL, MinIO, NATS, and Meilisearch
  access out of Flutter.
- Material color editing, cart persistence, signed URLs, and live device proof
  remain deferred.

## Design Notes

- Commands: none added.
- Queries: product detail is still loaded through `CatalogRepository`.
- API: reuses `GET /catalog/products/{id}?tier=low|high` and the returned
  `modelUrl`; no new API routes.
- Tables: none.
- Domain rules: the viewer renders only the model route selected by the
  existing product-detail tier.
- UI surfaces: Product Detail ready state.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-038 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart analysis and widget tests cover injected viewer source, route retention, and unavailable model state. |
| Integration | Static verifier confirms dependency, provider wiring, Android WebView localhost allowance, docs, and non-goals. |
| E2E | Not required; no live backend or live device proof in this slice. |
| Platform | Not required; Flutter Bazel rules and live device proof remain deferred. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `flutter pub get` resolved `model_viewer_plus 1.9.3` for the repository's
  Dart 3.9.2 SDK constraint.
- `dart format --set-exit-if-changed lib test` passed for
  `apps/mobile-flutter`.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 24 tests.
- `bash scripts/verify-us-038.sh` passed.
