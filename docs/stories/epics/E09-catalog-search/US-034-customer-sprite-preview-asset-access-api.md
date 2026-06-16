# US-034 Customer Sprite Preview Asset Access API

## Status

implemented

## Lane

normal

## Product Contract

Customer clients can request the processed 360-degree sprite for one catalog
product through the Go API gateway. The API reads the authoritative product row,
requires completed processing and a `lumin-360-sprites` object reference, and
streams the JPEG from MinIO. Mobile clients remain behind the API boundary and
do not connect directly to MinIO.

This story also checks in `resources/pet_tag_360_sprite.jpg`, generated from
`resources/pet_tag.glb` with the existing worker Blender renderer, as a stable
sprite fixture for later preview work.

This story does not add Flutter preview activation, product detail, signed
object URLs, category taxonomy, cart persistence, authentication,
authorization, retry/outbox semantics, dead-letter handling, or live K3d proof.

## Relevant Product Docs

- `docs/product/roadmap.md`
- `docs/product/mobile-commerce.md`
- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`

## Acceptance Criteria

- `GET /catalog/products/{id}/sprite` is routed through the Go API gateway.
- Invalid product ids return `400`.
- Missing products return `404`.
- Products without completed sprite output return `404`.
- Completed products with a sprite asset stream `image/jpeg` from the
  `lumin-360-sprites` bucket.
- Runtime wiring uses the existing MinIO client inside the API gateway; clients
  never receive direct MinIO credentials or a MinIO service URL.
- `resources/pet_tag_360_sprite.jpg` is a 960-by-640 JPEG generated from
  `resources/pet_tag.glb` with 24 frames, 6 columns, and 160-pixel frames.

## Design Notes

- Commands: none.
- Queries: the route reads the authoritative product row from PostgreSQL before
  reading the sprite object.
- API: `GET /catalog/products/{id}/sprite` returns binary `image/jpeg`.
- Tables: no schema changes.
- Domain rules: only `completed` products with a `lumin-360-sprites` object ref
  expose sprite bytes.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-034 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go tests cover sprite route success, invalid id, incomplete product, storage failure, and route wiring. |
| Integration | Static verifier confirms docs, route wiring, MinIO adapter, shared contract note, pet-tag sprite fixture, and non-goals. |
| E2E | Not required; no Flutter preview workflow exists in this story. |
| Platform | Not required; no live K3d proof is required in this story. |
| Release | Not required. |

## Harness Delta

No Harness behavior changes were required.

## Evidence

- `resources/pet_tag_360_sprite.jpg` generated with Blender 5.0.1 from
  `resources/pet_tag.glb`.
- Sprite fixture SHA-256:
  `23eae501e2de09d32c62a144b95e4d1a399dee3611b57b0d96c7944ecb649866`.
