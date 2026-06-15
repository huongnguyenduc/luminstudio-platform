# US-018 Admin Product Read HTTP API

## Status

implemented

## Lane

normal

## Product Contract

The Go API exposes read-only administrator product endpoints on top of the
Phase 2 product persistence foundation. `GET /admin/products` returns persisted
product records from PostgreSQL-backed storage. `GET /admin/products/{id}`
validates the v1 product identity path segment and returns one persisted product
record or a JSON 404 error when the product does not exist.

This story does not add admin UI behavior, product update/delete workflows,
MinIO uploads, NATS publication or consumption, worker processing, search
synchronization, authentication, authorization, filtering, pagination, or live
K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/api-gateway` routes `GET /admin/products` and
  `GET /admin/products/{id}` through the existing standard-library HTTP server
  without introducing a new web framework.
- The list endpoint returns JSON product records from PostgreSQL-backed product
  storage in deterministic updated-time order.
- The get endpoint validates the v1 product ID path segment before persistence
  access.
- Missing products return HTTP 404 with the existing JSON error envelope.
- Verification proves native Go tests, Bazel tests, route wiring, product
  handler behavior, store query behavior, docs updates, and story non-goals
  without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-018.sh`.
- Queries: admin product list and get read from PostgreSQL-backed product
  storage.
- API: `GET /admin/products`, `GET /admin/products/{id}`.
- Tables: `products`.
- Domain rules: product record validation remains aligned with
  `packages/shared-types/contracts/v1`; product IDs are validated before get
  persistence access.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-018 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go and Bazel tests cover product handler read behavior, route wiring, and ID validation. |
| Integration | Bazel builds and tests the API gateway target with product read routes wired into the binary. |
| E2E | Not required; no browser/mobile workflow exists in this story. |
| Platform | Not required; no live K3d database or HTTP smoke is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-018.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel tests passed for `//services/api-gateway:api_gateway_test` and
  `//services/api-gateway/internal/product:product_test`.
- Bazel built `//services/api-gateway:api-gateway`.
- Static verification found `GET /admin/products`,
  `GET /admin/products/{id}`, product handler read behavior, product store read
  SQL, route wiring, docs updates, and story non-goals.
