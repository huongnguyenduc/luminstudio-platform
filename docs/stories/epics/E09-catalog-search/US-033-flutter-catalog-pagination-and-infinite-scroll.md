# US-033 Flutter Catalog Pagination And Infinite Scroll

## Status

implemented

## Lane

normal

## Product Contract

The customer Flutter app loads additional catalog pages from the existing Go
API catalog boundary as the Home list approaches the end. Pagination uses the
existing `limit` and `offset` parameters on `GET /catalog/products` and
`GET /catalog/search?q=...`, stays behind the repository/use-case boundary, and
preserves the current search, clear, loading, empty, failure, and ready states.

This story does not add category taxonomy, sorting controls, 360-degree sprite
preview activation, signed object URLs, product detail, cart persistence,
Flutter Bazel rules, authentication, authorization, live backend proof,
emulator proof, or device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- The catalog Cubit tracks the current page size, offset, total, and whether
  more products can be requested for both normal catalog browsing and search
  results.
- The Home tab requests the next page through `GET /catalog/products` or
  `GET /catalog/search?q=...` when the visible list approaches the end.
- Additional pages append to the existing product list without replacing
  already-rendered products, losing the current search query, or resetting the
  Home tab scroll state.
- Incremental load failures show an inline retry control while preserving the
  existing page results.
- Widget tests cover initial pagination, search pagination, end-of-list state,
  and incremental load failure/retry.
- Verification proves Flutter formatting, analysis, tests, docs updates,
  route/contract alignment, and story non-goals without requiring live backend,
  K3d, emulator, or simulator proof.

## Design Notes

- Commands: `bash scripts/verify-us-033.sh`.
- Queries: Flutter calls the Go API catalog routes through the existing adapter.
- API: `GET /catalog/products?limit=...&offset=...`,
  `GET /catalog/search?q=...&limit=...&offset=...`.
- Tables: none added.
- Domain rules: mobile clients remain behind the Go API boundary; categories,
  sorting, signed URLs, previews, product detail, and cart behavior remain
  later stories.
- UI surfaces: Home tab catalog list pagination footer and inline retry state.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-033 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart and Flutter tests cover paginated catalog and search loading, append behavior, end-of-list behavior, retry, and existing shell/search states. |
| Integration | Flutter static analysis and the repository verifier confirm route parameters, docs, story packet, and non-goals. |
| E2E | Not required; no live backend, emulator, simulator, or device-run user flow is introduced. |
| Platform | Not required; no live K3d proof or Flutter Bazel rules are required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-033.sh` passed.
- `flutter pub get` resolved dependencies in `apps/mobile-flutter`.
- `dart format --set-exit-if-changed lib test` passed in
  `apps/mobile-flutter`.
- `flutter analyze` passed in `apps/mobile-flutter`.
- `flutter test` passed 15 catalog, pagination, search, retry, and shell tests.
