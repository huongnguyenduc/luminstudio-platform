# US-022 Admin Source GLB Upload And Task Event

## Status

implemented

## Lane

normal

## Product Contract

The Go API exposes an administrator source GLB upload endpoint for existing
products. `POST /admin/products/{id}/source-glb` accepts one multipart `.glb`
file in the `source` field, validates that the product exists and already has
mesh color configuration, stores the source asset in the `lumin-source-glb`
MinIO bucket, updates the product row with the source asset reference and
`queued` processing status, publishes `product.updated`, and publishes a v1
`3d.task.created` event for the later worker processing path.

This story does not add admin UI behavior, worker mesh optimization, 360-degree
rendering, `3d.task.completed` consumption, retry/outbox semantics,
dead-letter handling, authentication, authorization, customer catalog/search
HTTP routes, mobile behavior, or live K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/api-gateway` routes `POST /admin/products/{id}/source-glb` through
  the existing standard-library HTTP server.
- The handler validates the product id, reads the authoritative product record
  from PostgreSQL-backed product storage, and rejects source uploads until the
  product has valid mesh color configuration.
- The upload accepts multipart field `source`, rejects empty or non-`.glb`
  filenames, and stores the object under
  `lumin-source-glb/products/{productId}/source.glb` with content type
  `model/gltf-binary`.
- The product store updates `source_asset`, sets `processing_status` to
  `queued`, and returns the updated authoritative product record.
- The API publishes `product.updated` after queuing the source asset and then
  publishes a v1 `3d.task.created` event with task identity, product identity,
  source asset reference, mesh color configuration, and correlation identity.
- Verification proves native Go tests, Bazel tests, API gateway build, upload
  handler behavior, MinIO adapter shape, NATS task event publication shape,
  docs updates, and story non-goals without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-022.sh`.
- Queries: upload handling reads the product record and updates source asset
  state through PostgreSQL-backed product storage.
- API: `POST /admin/products/{id}/source-glb`.
- Tables: `products`.
- Events: `product.updated`, `3d.task.created`.
- Objects: MinIO bucket `lumin-source-glb`, key
  `products/{productId}/source.glb`.
- Domain rules: source uploads require valid mesh color configuration before a
  processing task event can be published.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-022 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go and Bazel tests cover source upload validation, object-store handoff, queued product state, product.updated publication, 3d.task.created construction, route exposure, and store argument encoding. |
| Integration | Bazel builds and tests the API gateway target with source upload runtime wiring. |
| E2E | Not required; no browser/mobile workflow exists in this story. |
| Platform | Not required; no live K3d MinIO or NATS proof is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-022.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel tests passed for `//services/api-gateway:api_gateway_test`,
  `//services/api-gateway/internal/product:product_test`, and
  `//services/api-gateway/internal/search:search_test`.
- Bazel built `//services/api-gateway:api-gateway`.
- Static verification found source upload route wiring, MinIO object-store
  adapter, queued product source state, `3d.task.created` event construction
  and publication, docs updates, and story non-goals.
