# US-020 Admin Product Mutation Event Publication

## Status

implemented

## Lane

normal

## Product Contract

The Go API publishes one v1 `product.updated` event after a successful
administrator product creation or full-replacement update. The event contains a
stable event envelope, correlation identifier, product identity, and changed
timestamp so later search synchronization can update Meilisearch without making
admin product mutations depend on search availability.

This story does not add admin UI behavior, product delete workflows, partial
PATCH semantics, MinIO uploads, search synchronization, Meilisearch writes,
worker processing, retry/outbox semantics, authentication, authorization,
filtering, pagination, or live K3d platform proof.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/api-gateway` creates a v1 `product.updated` event with envelope
  type `product.updated`, schema version `v1`, event identity, correlation
  identity, product identity, and changed timestamp after successful
  `POST /admin/products` and `PUT /admin/products/{id}` persistence.
- The HTTP handler propagates `X-Correlation-ID` when present and generates a
  valid correlation identity when the header is absent.
- Invalid `X-Correlation-ID` values are rejected before product persistence.
- The runtime API gateway wires a NATS-backed product event publisher from
  `NATS_URL` without introducing a new web framework or NATS client dependency.
- Event publication failure is surfaced as an HTTP 502 error before returning a
  product mutation response.
- Verification proves native Go tests, Bazel tests, route wiring, event payload
  behavior, NATS publish adapter wiring, docs updates, and story non-goals
  without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-020.sh`.
- Queries: none added.
- API: `POST /admin/products`, `PUT /admin/products/{id}`.
- Tables: `products`.
- Domain rules: `product.updated` stays aligned with
  `packages/shared-types/contracts/v1/events.schema.json`; publication happens
  after PostgreSQL persistence returns the authoritative product record.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-020 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go and Bazel tests cover product.updated construction, handler publication for create and update, correlation validation and propagation, generated correlation fallback, and publisher failure responses. |
| Integration | Bazel builds and tests the API gateway target with NATS-backed event publisher wiring. |
| E2E | Not required; no browser/mobile workflow exists in this story. |
| Platform | Not required; no live K3d NATS publish proof is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-020.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel tests passed for `//services/api-gateway:api_gateway_test` and
  `//services/api-gateway/internal/product:product_test`.
- Bazel built `//services/api-gateway:api-gateway`.
- Static verification found `product.updated` event construction, create and
  update publication hooks, correlation propagation, NATS publisher wiring,
  docs updates, and story non-goals.
