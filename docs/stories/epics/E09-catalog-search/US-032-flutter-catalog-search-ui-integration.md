# US-032 Flutter Catalog Search UI Integration

## Status

implemented

## Lane

normal

## Product Contract

The customer Flutter app exposes catalog search from the Home tab. Search
queries go through the Go API `GET /catalog/search?q=...` route behind the
existing repository/use-case boundary, and results render with the same
customer-safe product card shape as catalog browsing. The mobile client stays
behind the API boundary and does not connect directly to Meilisearch,
PostgreSQL, MinIO, or NATS.

This story does not add category taxonomy, sorting, pagination controls,
360-degree sprite preview activation, signed object URLs, product detail, cart
persistence, Flutter Bazel rules, authentication, authorization, live backend
proof, emulator proof, or device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- `apps/mobile-flutter` extends the catalog repository and use-case boundary
  with search behavior that calls `GET /catalog/search?q=...`.
- The Home tab exposes a search field with submit, clear, loading, empty,
  failure/retry, and ready states.
- Search results reuse the existing catalog product card rendering and preserve
  the existing preview-ready label when a result contains a `spriteAsset`.
- Empty queries return to the normal `GET /catalog/products` catalog list.
- Widget tests cover search submit, clear, empty search results, search
  failure/retry, and existing shell/catalog states.
- Verification proves Flutter formatting, analysis, tests, docs updates,
  route/contract alignment, and story non-goals without requiring live backend,
  K3d, emulator, or simulator proof.

## Design Notes

- Commands: `bash scripts/verify-us-032.sh`.
- Queries: Flutter calls the Go API catalog search route through an adapter.
- API: `GET /catalog/search?q=...`.
- Tables: none added.
- Domain rules: mobile clients remain behind the Go API boundary; categories,
  product detail, signed URLs, previews, and cart behavior remain later
  stories.
- UI surfaces: Home tab catalog search field and result states.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-032 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart and Flutter tests cover catalog search DTO tolerance, Cubit-backed UI states, retry, clear, and shell state retention. |
| Integration | Flutter static analysis and the repository verifier confirm route, contract, docs, and non-goals. |
| E2E | Not required; no live backend, emulator, simulator, or device-run user flow is introduced. |
| Platform | Not required; no live K3d proof or Flutter Bazel rules are required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-032.sh` passed.
- `flutter pub get` resolved dependencies in `apps/mobile-flutter`.
- `dart format --set-exit-if-changed lib test` passed in
  `apps/mobile-flutter`.
- `flutter analyze` passed in `apps/mobile-flutter`.
- `flutter test` passed catalog search, catalog list, retry, and shell tests.
