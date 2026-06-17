# US-055 Flutter UI UX Audit Capture Harness

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer app must have a deterministic UI audit capture harness for
the current commerce surfaces: Home, Category, Product Detail top, Product
Detail scrolled customization, and Cart. The harness uses fake repositories and
widget-driven capture so UI review does not depend on a running API gateway,
manual simulator navigation, or stale nested navigation state.

This story does not change checkout, payments, authentication, inventory,
shipping, tax, order fulfillment, API contracts, backend cart behavior, or
direct service access rules.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/stories/backlog.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- A repeatable Flutter test captures mobile-size screenshots for Home,
  Category, Product Detail top, Product Detail scrolled customization, and Cart
  under `reports/ui-ux-review/`.
- The capture path uses fake repositories and injected product model viewer
  behavior rather than requiring PostgreSQL, MinIO, NATS, Meilisearch, K3d, or a
  live Go API gateway.
- A story verifier runs format, analyze, the capture test with golden update,
  and the full Flutter test suite.
- Product docs and Harness durable proof records describe the audit harness
  without claiming a UX redesign implementation.

## Design Notes

- Commands: `bash scripts/verify-us-055.sh`
- Queries: none
- API: no new API routes or contract changes
- Tables: none
- Domain rules: no cart, product, pricing, or category semantics change
- UI surfaces: Home, Category, Product Detail, Cart captured for review only

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-055 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Flutter widget capture test uses fake repositories and asserts expected UI anchors before screenshots. |
| Integration | `flutter analyze` and full `flutter test` pass for `apps/mobile-flutter`. |
| E2E | Not required; this story intentionally avoids live backend/simulator dependency. |
| Platform | Mobile-size screenshot artifacts are produced under `reports/ui-ux-review/`. |
| Release | Not required. |

## Harness Delta

Adds a deterministic UI audit capture verifier so future UI/UX review starts
from stable evidence instead of manual simulator state.

## Evidence

`bash scripts/verify-us-055.sh` passed on 2026-06-16. The verifier ran
`flutter pub get`, `dart format --set-exit-if-changed lib test`,
`flutter analyze`, `flutter test test/us055_ui_audit_capture_test.dart
--update-goldens`, and full `flutter test`.

Generated audit artifacts:

- `reports/ui-ux-review/us055-home.png`
- `reports/ui-ux-review/us055-category.png`
- `reports/ui-ux-review/us055-detail-top.png`
- `reports/ui-ux-review/us055-detail-customization.png`
- `reports/ui-ux-review/us055-cart.png`
