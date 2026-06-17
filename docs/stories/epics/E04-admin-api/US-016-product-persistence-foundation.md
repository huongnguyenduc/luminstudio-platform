# US-016 Product Persistence Foundation

## Status

implemented

## Lane

normal

## Product Contract

The Go API owns the first relational product record shape for Phase 2 product
administration. Product drafts can be validated against the shared contract
rules before persistence, and PostgreSQL has an explicit schema for product
identity, slug uniqueness, dynamic information sections, mesh color
configuration, source and processed asset references, processing status, and
timestamps.

This story does not add HTTP routes, admin UI behavior, MinIO uploads, NATS
publication or consumption, worker processing, search synchronization,
authentication, or authorization.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `services/api-gateway` contains a product persistence package with typed
  product draft, record, mesh color, information section, object reference, and
  processing status models aligned to `packages/shared-types/contracts/v1`.
- Product draft validation rejects malformed slugs, empty required strings,
  invalid mesh IDs, invalid hex colors, duplicate allowed colors, missing
  default colors from the allowed set, and invalid MinIO asset references.
- `services/api-gateway/migrations` contains the initial PostgreSQL product
  table definition with slug uniqueness, processing status constraints, JSONB
  columns for dynamic sections and asset/config payloads, and timestamp fields.
- Bazel exposes and tests the product persistence package and exposes the
  migration SQL as a build target.
- Verification proves native Go tests, Bazel tests, migration syntax guardrails,
  and story non-goals without requiring live K3d services.

## Design Notes

- Commands: `bash scripts/verify-us-016.sh`.
- Queries: product list/read queries are deferred until API routes are added.
- API: no HTTP API is added in this story.
- Tables: `products`.
- Domain rules: product slugs use the v1 shared contract pattern; mesh color
  configuration maps stable mesh IDs to a default hex color and one or more
  unique allowed hex colors; the default color must be allowed.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-016 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Native Go and Bazel tests cover product draft validation and persistence argument encoding. |
| Integration | Bazel builds the product package and migration SQL target. |
| E2E | Not required; no user-facing workflow exists in this story. |
| Platform | Not required; the migration is defined but not applied to a live K3d database in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-016.sh` passed.
- Native Go tests passed for `services/api-gateway`.
- Bazel test passed for `//services/api-gateway/internal/product:product_test`.
- Bazel built `//services/api-gateway/migrations:migrations`.
- Static verification found the `products` table, processing status enum,
  product JSONB columns, validation model types, and story non-goals.
