# US-019 Admin Product Update HTTP API

## Status

implemented

## Lane

normal

## Product Contract

The Go API exposes a full-replacement administrator product update endpoint on
top of the Phase 2 product persistence foundation. `PUT /admin/products/{id}`
validates the v1 product identity path segment and one v1 product draft JSON
body, updates the existing PostgreSQL product row, preserves server-owned
identity, creation time, processing status, and processed asset references, and
returns the updated product record.

This story does not add admin UI behavior, product delete workflows, partial
PATCH semantics, MinIO uploads, NATS publication or consumption, worker
processing, search synchronization, authentication, authorization, filtering,
pagination, or live K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/api-gateway` routes `PUT /admin/products/{id}` through the existing
  standard-library HTTP server without introducing a new web framework.
- The endpoint validates the v1 product ID path segment before persistence
  access.
- The endpoint parses one JSON product draft, rejects malformed JSON, unknown
  trailing JSON, and invalid product drafts before persistence.
- Missing products return HTTP 404 with the existing JSON error envelope.
- Successful updates return HTTP 200 and the updated JSON `ProductRecord`.
- Verification proves native Go tests, Bazel tests, route wiring, product
  handler behavior, store update behavior, docs updates, and story non-goals
  without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-019.sh`.
- Queries: admin product update writes to PostgreSQL-backed product storage.
- API: `PUT /admin/products/{id}`.
- Tables: `products`.
- Domain rules: product draft validation remains aligned with
  `packages/shared-types/contracts/v1`; product IDs are validated before update
  persistence access; server-owned processing fields are preserved by the SQL
  update.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-019 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go and Bazel tests cover product handler update behavior, route wiring, ID validation, draft validation, and store update argument encoding. |
| Integration | Bazel builds and tests the API gateway target with product update routes wired into the binary. |
| E2E | Not required; no browser/mobile workflow exists in this story. |
| Platform | Not required; no live K3d database or HTTP smoke is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-019.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel tests passed for `//services/api-gateway:api_gateway_test` and
  `//services/api-gateway/internal/product:product_test`.
- Bazel built `//services/api-gateway:api-gateway`.
- Static verification found `PUT /admin/products/{id}`, product handler update
  behavior, product store update SQL, route wiring, docs updates, and story
  non-goals.
