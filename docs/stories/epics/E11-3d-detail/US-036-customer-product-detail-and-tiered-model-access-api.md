# US-036 Customer Product Detail And Tiered Model Access API

## Status

implemented

## Lane

normal

## Product Contract

Customer clients can request one product detail record through the Go API
gateway with `GET /catalog/products/{id}?tier=low|high`. The API reads the
authoritative PostgreSQL product row, requires completed processing, and returns
seller-provided information sections, mesh color configuration, sprite access,
and a gateway model route for the requested device tier.

Customers can request GLB bytes through
`GET /catalog/products/{id}/model?tier=low|high`. The low tier streams the
processed optimized GLB from `lumin-optimized-glb`; the high tier streams the
original source GLB from `lumin-source-glb`. Both routes stay behind the API
gateway and never expose MinIO credentials, direct MinIO service URLs, or
signed object URLs.

This story does not add Flutter device-tier detection, a Flutter 3D viewer,
material color editing behavior, related products, signed object URLs, cart
persistence, authentication, authorization, retry/outbox semantics,
dead-letter handling, or live K3d proof.

## Relevant Product Docs

- `docs/product/roadmap.md`
- `docs/product/mobile-commerce.md`
- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- `ProductDetailResponse` is defined in the v1 shared product contract.
- `GET /catalog/products/{id}` validates product identity and `tier`.
- Invalid product ids or tiers return `400`.
- Missing products return `404`.
- Products without completed matching model output return `404`.
- Product detail responses include dynamic information sections, mesh color
  configuration, `modelTier`, `modelAsset`, `modelUrl`, optional `spriteAsset`,
  optional `spriteUrl`, and `updatedAt`.
- `GET /catalog/products/{id}/model?tier=low` streams
  `model/gltf-binary` bytes from `lumin-optimized-glb`.
- `GET /catalog/products/{id}/model?tier=high` streams
  `model/gltf-binary` bytes from `lumin-source-glb`.
- Runtime wiring uses the existing MinIO client inside the API gateway; clients
  never receive direct MinIO credentials or a MinIO service URL.

## Design Notes

- Commands: none.
- Queries: both routes read the authoritative product row from PostgreSQL before
  reading any model object.
- API: `GET /catalog/products/{id}?tier=low|high` returns JSON;
  `GET /catalog/products/{id}/model?tier=low|high` returns binary GLB.
- Tables: no schema changes.
- Domain rules: only `completed` products with the matching source or optimized
  object reference expose model detail or bytes.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-036 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go tests cover product detail success, invalid tier, missing model output, low/high model streaming, storage failure, and route wiring. |
| Integration | Static verifier confirms shared contract, docs, route wiring, MinIO adapter, and non-goals. |
| E2E | Not required; no Flutter viewer or live backend workflow is introduced. |
| Platform | Not required; no live K3d proof is required in this story. |
| Release | Not required. |

## Harness Delta

No Harness behavior changes were required.

## Evidence

- `go test ./...` passed for `services/api-gateway`.
- `bash scripts/verify-us-036.sh` passed.
