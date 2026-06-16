# US-031 Flutter Catalog Products API Integration

## Status

implemented

## Lane

normal

## Product Contract

The customer Flutter app loads catalog product cards from the Go API
`GET /catalog/products` route and renders them in the Home tab. The mobile
client stays behind the API boundary and does not connect directly to
Meilisearch, PostgreSQL, MinIO, or NATS.

This story does not add catalog search UI, category taxonomy, sorting,
pagination controls, 360-degree sprite preview activation, signed object URLs,
product detail, cart persistence, Flutter Bazel rules, authentication,
authorization, or live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- `apps/mobile-flutter` has a catalog feature with domain product models,
  repository/use-case boundaries, HTTP adapter code for `GET /catalog/products`,
  and Cubit-owned loading, empty, ready, and failure states.
- The Home tab renders catalog products returned by the repository, including a
  preview-ready label when the response contains a `spriteAsset`.
- The app base URL is configurable with the Dart environment value
  `LUMIN_API_BASE_URL` and defaults to `http://localhost:8080` for local
  development.
- Widget tests cover empty, ready, failure/retry, bottom navigation, and
  retained Home scroll/nested navigation state.
- Verification proves Flutter formatting, analysis, tests, docs updates,
  route/contract alignment, and story non-goals without requiring live backend,
  K3d, emulator, or simulator proof.

## Design Notes

- Commands: `bash scripts/verify-us-031.sh`.
- Queries: Flutter calls the Go API catalog products route through an adapter.
- API: `GET /catalog/products`.
- Tables: none added.
- Domain rules: mobile clients remain behind the Go API boundary; catalog
  search, categories, product detail, signed URLs, previews, and cart behavior
  remain later stories.
- UI surfaces: Home tab catalog list in the Flutter customer app.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-031 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart and Flutter tests cover catalog DTO parsing, Cubit-backed UI states, retry, and shell state retention. |
| Integration | Flutter static analysis and the repository verifier confirm route, contract, docs, and non-goals. |
| E2E | Not required; no live backend, emulator, simulator, or device-run user flow is introduced. |
| Platform | Not required; no live K3d proof or Flutter Bazel rules are required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-031.sh` passed.
- `flutter pub get` resolved dependencies in `apps/mobile-flutter`.
- `dart format --set-exit-if-changed lib test` passed in
  `apps/mobile-flutter`.
- `flutter analyze` passed in `apps/mobile-flutter`.
- `flutter test` passed 8 catalog and shell tests.
