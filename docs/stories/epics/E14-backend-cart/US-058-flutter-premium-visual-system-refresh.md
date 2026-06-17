# US-058 Flutter Premium Visual System Refresh

## Status

implemented

## Lane

normal

## Product Contract

Refresh the existing Flutter customer app visual system so the implemented
commerce surfaces feel more premium, product-led, and app-native. The refresh
updates theme, spacing, surface hierarchy, navigation treatment, and shared
commerce presentation language while preserving the existing Flutter
feature-oriented architecture, BLoC/Cubit state ownership, navigation behavior,
API boundaries, cart behavior, and product contracts.

This story does not add checkout, payments, authentication, authorization,
inventory checks, tax, shipping, order fulfillment, backend contract changes,
signed object URLs, new model delivery behavior, or direct PostgreSQL, MinIO,
NATS, or Meilisearch access from Flutter.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/stories/backlog.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- Harness UI skill providers for mobile visual direction and Flutter
  implementation report present before implementation.
- The Flutter app uses a more premium, product-led visual system with refined
  typography, calmer surfaces, stronger spacing, and a less one-note palette
  across Home, Category, Product Detail, and Cart.
- Home and Category product cards retain the existing repository, pagination,
  search, category, and detail-navigation behavior while improving scan
  hierarchy and reducing cheap-looking chip/card clutter.
- Product Detail and Cart retain their existing model, customization, add to
  cart, sync, selection, quantity, and subtotal behavior while matching the
  refreshed visual language.
- Deterministic mobile-size audit screenshots are refreshed through the
  existing fake-repository capture harness.
- Existing Flutter widget, repository, cart sync, loading, empty, failure, and
  navigation tests continue to pass.

## Design Notes

- Commands: existing Flutter Cubit, repository, and navigation commands only.
- Queries: existing Go API-backed catalog/category/detail/cart repository
  methods only.
- API: no new public API shape or route.
- Tables: none.
- Domain rules: no product, category, pricing, cart, model-tier, or color
  validation semantics change.
- UI surfaces: Flutter app theme, shell navigation, Home catalog, Category
  browse, Product Detail, and Cart.
- Selected skills: `imagegen-frontend-mobile` for premium mobile visual
  reference, `flutter-expert` for Flutter implementation constraints.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-058 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Flutter widget tests continue to cover shell, catalog, category, detail, customization, and cart behavior. |
| Integration | `flutter analyze` and full `flutter test` pass for `apps/mobile-flutter`. |
| E2E | Not required; this story changes visual presentation without backend contract changes. |
| Platform | Deterministic 390x844 audit screenshots under `reports/ui-ux-review/` are refreshed for Home, Category, Product Detail, and Cart. |
| Release | Deferred. |

## Harness Delta

No Harness policy changes expected. This story reuses the existing US-055
deterministic UI audit capture harness and UI skill registry.

## Evidence

- `bash scripts/verify-us-058.sh` passed on 2026-06-17.
- `scripts/bin/harness-cli story verify US-058` passed on 2026-06-17.
- The verifier ran `flutter pub get`, `dart format --set-exit-if-changed lib
  test`, `flutter analyze`, refreshed deterministic audit goldens, and ran the
  full Flutter test suite.
- Refreshed audit artifacts:
  - `reports/ui-ux-review/us055-home.png`
  - `reports/ui-ux-review/us055-category.png`
  - `reports/ui-ux-review/us055-detail-top.png`
  - `reports/ui-ux-review/us055-detail-customization.png`
  - `reports/ui-ux-review/us055-cart.png`
  - `reports/us-040/cart-local-persistence.png`
