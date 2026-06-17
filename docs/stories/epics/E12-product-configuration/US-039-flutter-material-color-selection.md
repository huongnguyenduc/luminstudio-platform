# US-039 Flutter Material Color Selection

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer product detail screen lets customers select material colors
for each configured mesh identifier returned by the Go API product-detail
response. The screen initializes each mesh to its configured default color,
renders allowed colors as touchable swatches, and keeps the active selection in
`ProductDetailCubit` state for later cart use.

The selection uses only the existing `meshColorConfig` returned by
`GET /catalog/products/{id}?tier=low|high`. Mobile clients continue to stay
behind the Go API gateway and do not connect directly to PostgreSQL, MinIO,
NATS, or Meilisearch.

This story does not add cart persistence, related products, category taxonomy,
sorting controls, signed object URLs, authentication, authorization, Flutter
Bazel rules, live backend proof, or live device proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- Product Detail initializes selected mesh colors from each mesh color
  configuration default.
- Allowed colors render as touchable swatches with stable keys and accessibility
  labels.
- Tapping an allowed color updates `ProductDetailCubit` selected color state.
- Tapping an unsupported color is ignored by the Cubit.
- The selected swatch is visually distinct from unselected swatches.
- Widget tests cover default selection, swatch interaction, and selected state.
- Verification captures a mobile-size Product Detail screenshot after selecting
  a non-default color.
- The implementation keeps direct PostgreSQL, MinIO, NATS, and Meilisearch
  access out of Flutter.

## Design Notes

- Commands: none added.
- Queries: product detail is still loaded through `CatalogRepository`.
- API: reuses `GET /catalog/products/{id}?tier=low|high` and the returned
  `meshColorConfig`; no new API routes.
- Tables: none.
- Domain rules: selected colors must match the allowed color list for the mesh.
- UI surfaces: Product Detail configurable colors section.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-039 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart analysis and widget tests cover selected color defaults and tap interaction. |
| Integration | Static verifier confirms Cubit state, UI keys/semantics, docs, non-goals, and mobile screenshot capture. |
| E2E | Not required; no live backend or live device proof in this slice. |
| Platform | Not required; Flutter Bazel rules and live device proof remain deferred. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `dart format --set-exit-if-changed lib test` passed for
  `apps/mobile-flutter`.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 25 tests.
- `bash scripts/verify-us-039.sh` passed.
- Mobile viewport interaction capture saved at
  `reports/us-039/product-detail-material-selection.png`; the capture shows
  Product Detail after selecting the non-default `#0F172A` `mesh_body` swatch.
