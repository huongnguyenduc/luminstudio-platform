# US-057 Catalog And Category Browse Ergonomics

## Status

implemented

## Lane

normal

## Product Contract

Improve the existing Flutter customer browse flow so Home and Category product
lists are easier to scan, category and sort choices are faster to change, and
customers can open product detail from consistent product cards without adding
new backend contracts.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Home catalog cards expose a stable customer-readable category cue, price,
  preview state, and detail affordance without requiring horizontal scrolling.
- Category browse uses fast touch controls for category and sort selection, with
  the selected category and selected sort visible at the top of the product
  list.
- Category product cards match the Home product card hierarchy for image,
  category, price, preview state, and detail affordance.
- Deterministic mobile-size audit screenshots are refreshed for Home and
  Category through the existing fake-repository harness.
- No checkout, payment, authentication, inventory, order, backend cart contract,
  or direct platform-service access is introduced.

## Design Notes

- Commands: category and sort selections stay inside existing Cubit methods.
- Queries: existing Go API catalog/category repository methods only.
- API: no new public API shape.
- Tables: none.
- Domain rules: no product/category/sort value changes.
- UI surfaces: Flutter Home tab and Category tab product browse surfaces.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-057 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Flutter widget tests cover category sort tap and browse card labels. |
| Integration | Flutter test suite exercises existing fake repositories and navigation. |
| E2E | Not required; no live backend/simulator behavior change. |
| Platform | Deterministic 390x844 audit screenshots refreshed for Home and Category. |
| Release | Deferred. |

## Harness Delta

No Harness behavior changes expected. This story reuses the US-055 deterministic
UI audit capture harness.

## Evidence

- `bash scripts/verify-us-057.sh` passed.
- `scripts/bin/harness-cli story verify US-057` passed.
- `flutter analyze` passed inside the verifier.
- Full `flutter test` passed inside the verifier.
- Deterministic mobile-size audit screenshots refreshed under
  `reports/ui-ux-review/`.
