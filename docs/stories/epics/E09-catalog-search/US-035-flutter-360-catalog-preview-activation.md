# US-035 Flutter 360 Catalog Preview Activation

## Status

implemented

## Lane

normal

## Product Contract

The Flutter Home tab activates a catalog-card 360-degree preview for products
that expose a sprite asset through the Go API boundary. A product card that is
at least 80% visible and idle for three seconds swaps its preview icon for the
API-served sprite sheet and animates through the 24-frame, 6-by-4 sprite
contract. Leaving visibility or resuming scroll cancels pending activation and
stops an active preview.

Mobile clients remain behind the Go API gateway. The Flutter UI receives a
`GET /catalog/products/{id}/sprite` URL from the catalog API adapter and never
constructs or requests direct MinIO URLs.

This story does not add category taxonomy, sorting controls, product detail,
signed object URLs, device-tier GLB selection, cart persistence, Flutter Bazel
rules, authentication, authorization, live backend proof, or live device proof.

## Relevant Product Docs

- `docs/product/roadmap.md`
- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- `apps/mobile-flutter` depends on `visibility_detector` for product-card
  visibility measurement.
- Catalog API DTO/domain mapping attaches a Go API sprite route URI only when a
  catalog item includes `spriteAsset`.
- Product cards with sprite preview URLs schedule activation only after they
  are at least 80% visible and scrolling is idle for three seconds.
- Resuming scroll or dropping below the visibility threshold cancels pending
  activation and stops active preview rendering.
- Active preview rendering uses `Image.network` against
  `GET /catalog/products/{id}/sprite` and displays the 24-frame, 6-column,
  4-row sprite sheet as a cropped animated frame.
- Widget tests cover preview activation and cancellation without direct MinIO,
  PostgreSQL, NATS, or Meilisearch access.

## Design Notes

- Commands: none.
- Queries: Flutter still calls the existing catalog/search API routes through
  the catalog repository.
- API: sprite bytes are requested through
  `GET /catalog/products/{id}/sprite`.
- Tables: no schema changes.
- Domain rules: a product can preview only when the catalog response contains a
  sprite asset and the adapter can derive a Go API sprite route.
- UI surfaces: Home tab product cards.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-035 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart and Flutter tests cover sprite route URI mapping, preview activation, cancellation during scroll, and existing shell/catalog/search/pagination states. |
| Integration | Flutter formatting, analysis, and the repository verifier confirm dependency, docs, story packet, route boundary, and non-goals. |
| E2E | Not required; no live backend or live device workflow is required in this story. |
| Platform | Not required; no live K3d proof or Flutter Bazel rules are required in this story. |
| Release | Not required. |

## Harness Delta

No Harness behavior changes were required.

## Evidence

- `flutter analyze` passed.
- `flutter test` passed 17 catalog, preview, pagination, search, retry, and
  shell tests.
