# US-043 Flutter Category Tab API Integration

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer app connects the Category tab to the existing Go API
category boundary. The tab lists customer-facing categories from
`GET /catalog/categories`, loads the selected category's products from
`GET /catalog/categories/{slug}/products`, supports the v1 sort values, and
paginates category product results through the existing catalog response
envelope.

The Flutter app remains behind the Go API gateway. It does not connect directly
to PostgreSQL, MinIO, NATS, or Meilisearch.

This story does not add checkout, payments, authentication, authorization,
inventory checks, backend cart APIs, signed object URLs, Flutter Bazel rules,
live backend proof, or live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- Flutter catalog domain models parse v1 category slug/name pairs and category
  product response metadata.
- The catalog repository exposes category-list and category-product use cases
  through the existing Go API boundary.
- The Category tab renders loading, empty, failure/retry, category selection,
  product loading, product empty, product failure/retry, and ready states.
- Category products support `newest`, `price_asc`, `price_desc`, and
  `name_asc` sorting through the API query parameter.
- Category products paginate with append behavior, end-of-list messaging, and
  inline retry for incremental load failures.
- The Category tab exposes a scroll-to-top control away from the top of the
  list.
- Product taps from Category still open the existing product detail flow through
  the repository/use-case boundary.
- Widget tests cover category loading, sort changes, pagination, and retry.
- Verification proves Flutter formatting, analysis, tests, docs updates, route
  alignment, and non-goals without requiring live backend, emulator,
  simulator, or device proof.

## Design Notes

- Commands: `bash scripts/verify-us-043.sh`.
- Queries: Flutter calls `GET /catalog/categories` and
  `GET /catalog/categories/{slug}/products?sort=...&limit=...&offset=...`.
- API: no new backend routes are added; this story consumes the `US-042`
  routes.
- Tables: none.
- Domain rules: category sort values use the v1 wire names from the shared
  contract; mobile clients stay behind the Go API gateway.
- UI surfaces: Flutter Category tab and product-detail navigation from category
  product rows.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-043 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart and Flutter tests cover category DTO parsing, category loading, sort changes, pagination, retry, and existing shell states. |
| Integration | Flutter formatting, analysis, and the repository verifier confirm route usage, docs, story packet, and non-goals. |
| E2E | Not required; no live backend, emulator, simulator, or device-run user flow is introduced. |
| Platform | Not required; no live K3d proof or Flutter Bazel rules are required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 33 tests covering
  category DTO parsing, category loading, sort changes, pagination, retry, and
  existing shell/catalog/detail/cart states.
- `bash scripts/verify-us-043.sh` passed, including Flutter dependency
  resolution, formatting, analysis, tests, static route checks, docs checks,
  and non-goals.
