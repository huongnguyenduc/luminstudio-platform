# US-060 Product Detail Model First Finish Polish

## Status

implemented

## Lane

normal

## Product Contract

Product Detail prioritizes the interactive model as the first-screen product
surface. Model, 360, and category metadata must be compact supporting text
rather than large tags. Finish selection must use customer-readable finish
names in the visible UI instead of raw color hex values, and the previous
standalone Selected finish card must not duplicate the customization flow.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/stories/backlog.md`

## Acceptance Criteria

- The Product Detail model panel is materially larger and remains the first
  dominant surface in the ready state.
- Model tier, 360 readiness, and category metadata render as compact inline
  support text rather than pill tags.
- The standalone Selected finish summary card is removed from the detail page.
- Visible selected finish labels and swatch accessibility labels use friendly
  names such as `Porcelain white` and `Midnight navy` instead of raw hex values.
- Existing detail loading, failure, swatch selection, Add to cart, Cart sync,
  Home, Category, and audit capture flows remain intact.

## Design Notes

- Commands: no new API commands.
- Queries: no new API queries.
- API: no backend contract changes; finish names are derived in Flutter for the
  existing color values.
- Tables: no database changes.
- Domain rules: selected mesh color values remain the existing hex values for
  cart payloads and validation.
- UI surfaces: Product Detail ready state and audit screenshots.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-060 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | `flutter test` covers Product Detail metadata, finish labels, swatch selection, and cart addition. |
| Integration | Product Detail widget tests run with fake repositories and injected model viewer. |
| E2E | Not required; no live backend/device behavior changes. |
| Platform | US-055 deterministic Product Detail audit screenshots refresh through the verifier. |
| Release | Deferred. |

## Harness Delta

None.

## Evidence

- `bash scripts/verify-us-060.sh` passed.
