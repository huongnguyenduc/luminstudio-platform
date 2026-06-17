# US-056 Product Detail Customize To Cart Ergonomics

## Status

implemented

## Lane

normal

## Product Contract

The Flutter Product Detail screen must make the customize-to-cart path faster
and easier to verify on a mobile viewport. Customers can see the current finish
selection near the product price, reach color customization without excessive
scrolling, and add the selected configuration to the cart from the persistent
bottom action after changing a swatch.

This story does not change checkout, payments, authentication, authorization,
inventory checks, shipping, tax, order fulfillment, API contracts, backend cart
behavior, or direct service access rules.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/stories/backlog.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- Product Detail uses a mobile-responsive 3D viewer height so the selected
  finish summary and customization entry are visible earlier on a 390 by 844
  viewport.
- Product Detail shows a customer-readable selected finish summary near the
  price and repeats the selected choice in the persistent Add to cart bar.
- Selecting a material swatch updates the visible selected finish summary, and
  the configured product can be added to cart without an extra scroll after the
  swatch selection.
- Deterministic UI audit screenshots are refreshed through the existing fake
  repository capture harness.
- No checkout, payment, auth, inventory, order, backend cart contract, or direct
  platform access behavior is introduced.

## Design Notes

- Commands: `bash scripts/verify-us-056.sh`
- Queries: none
- API: no new API routes or contract changes
- Tables: none
- Domain rules: no cart, product, pricing, or category semantics change
- UI surfaces: Flutter Product Detail only; existing Home, Category, and Cart
  capture artifacts are regenerated to keep the audit set current

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-056 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Flutter widget tests assert selected finish visibility, swatch summary updates, and add-to-cart after swatch selection. |
| Integration | `flutter analyze` and full `flutter test` pass for `apps/mobile-flutter`. |
| E2E | Not required; this story refines existing Flutter UI behavior without backend contract changes. |
| Platform | Mobile-size audit screenshots under `reports/ui-ux-review/` are refreshed through the deterministic capture harness. |
| Release | Not required. |

## Harness Delta

No Harness policy changes. This story reuses the `US-055` deterministic UI audit
capture harness as implementation proof.

## Evidence

`bash scripts/verify-us-056.sh` passed on 2026-06-16. The verifier ran
`flutter pub get`, `dart format --set-exit-if-changed lib test`,
`flutter analyze`, `flutter test test/us055_ui_audit_capture_test.dart
--update-goldens`, and full `flutter test`.

Updated audit artifacts:

- `reports/ui-ux-review/us055-home.png`
- `reports/ui-ux-review/us055-category.png`
- `reports/ui-ux-review/us055-detail-top.png`
- `reports/ui-ux-review/us055-detail-customization.png`
- `reports/ui-ux-review/us055-cart.png`
