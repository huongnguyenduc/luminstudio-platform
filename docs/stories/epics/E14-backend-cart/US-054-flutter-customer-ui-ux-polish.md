# US-054 Flutter Customer UI UX Polish

## Status

implemented

## Lane

normal

## Product Contract

The existing Flutter customer commerce surfaces are refined for a faster,
clearer browse, customize, and cart-review flow. Catalog cards now expose
category, price, preview readiness, and a clearer detail affordance. Product
Detail keeps model tier and preview status visible while moving Add to cart to
a persistent bottom action. Cart summary and item controls now use clearer
hierarchy, swatches, friendly mesh labels, and a compact quantity stepper.

This story does not add checkout, payments, authentication, authorization,
inventory checks, tax, shipping, order fulfillment, seller settlement, new
backend routes, new public contracts, or direct PostgreSQL, MinIO, NATS, or
Meilisearch access from Flutter.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- Harness UI skill registrations point at the repo-local `.codex/skills`
  directory and report present.
- Catalog cards remain behind the existing catalog repository boundary while
  showing category, price, preview readiness, and a clear detail affordance.
- Product Detail no longer shows internal model or sprite API routes to
  customers.
- Product Detail keeps customization near the purchase action and exposes a
  persistent Add to cart control for quicker cart creation.
- Cart uses customer-friendly color labels and visual swatches while retaining
  existing item selection and quantity behavior.
- Existing Flutter widget, repository, cart sync, loading, empty, failure, and
  golden coverage continues to pass.
- Simulator screenshots are captured for before/after UI review.

## Design Notes

- Selected UI skills: `redesign-existing-projects` for audit and
  `flutter-expert` for Flutter implementation constraints.
- Existing BLoC/Cubit ownership, feature-oriented structure, and API boundary
  remain unchanged.
- Visual polish is intentionally bounded to catalog, product detail, and cart.
  Checkout, payment, auth, inventory, shipping, and order workflows remain a
  later phase.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-054 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Flutter widget and repository tests pass. |
| Integration | Static verifier, `flutter analyze`, and `flutter test` pass. |
| E2E | Not required; no new backend flow or checkout behavior is added. |
| Platform | iPhone simulator screenshots cover Home, Product Detail, and Cart review states. |
| Release | Deferred. |

## Harness Delta

Adds `US-054` as a bounded UI polish story after live backend cart sync proof
and updates UI skill registration to the current repo-local skill root.

## Evidence

- `bash scripts/register-ui-skills.sh` refreshed all UI skill entries to
  `.codex/skills` and `query tools` reported relevant UI skills present.
- iPhone 17 Pro simulator screenshots were captured under
  `reports/ui-ux-review/`.
- `flutter analyze` passed in `apps/mobile-flutter`.
- `flutter test` passed in `apps/mobile-flutter`.
