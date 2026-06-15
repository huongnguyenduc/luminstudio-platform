# US-015 Define Phase 2 Product, Asset, And Event Contracts

## Status

implemented

## Lane

normal

## Product Contract

Phase 2 starts with versioned shared contracts for product administration,
source GLB asset references, mutable mesh color configuration, and the first
NATS events used by search synchronization and 3D processing.

The Go API remains the owner of product mutations, PostgreSQL state, object
storage coordination, and event publication. The Rust worker receives task
events, writes processed objects, and reports completion through events without
mutating relational state.

This story does not add HTTP routes, database migrations, UI behavior, NATS
runtime publication or consumption, worker processing, authentication, or
authorization.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `packages/shared-types` contains versioned JSON Schema sources for shared
  common types, product administration records, and product/processing events.
- The contracts include the initial mesh color configuration shape and MinIO
  asset bucket references for source GLB, optimized GLB, and 360 sprite assets.
- The contracts include `product.updated`, `3d.task.created`, and
  `3d.task.completed` payload shapes with correlation identifiers.
- Bazel exposes the contract sources as a build target.
- Verification proves the schema sources are parseable JSON and still excludes
  runtime behavior such as API routes, migrations, auth, worker processing, and
  NATS clients.

## Design Notes

- Commands: `bash scripts/verify-us-015.sh`.
- Queries: none.
- API: no HTTP API is added; contracts are source input for later API stories.
- Tables: no database tables or migrations are added.
- Domain rules: mesh color config maps stable mesh IDs to one default hex color
  and one or more allowed hex colors; source and processed assets are MinIO
  object references.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-015 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | JSON Schema files parse as JSON and contain required definitions, event names, buckets, and non-goal boundaries. |
| Integration | Bazel builds `//packages/shared-types:contracts_v1`. |
| E2E | Not required; no user-facing workflow exists in this story. |
| Platform | Not required; no K3d workload or live service behavior changes. |
| Release | Not required for contract source story. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-015.sh` passed.
- Node parsed `common.schema.json`, `product.schema.json`, and
  `events.schema.json` as JSON.
- Static assertions found required mesh config, MinIO bucket references,
  product/event names, correlation identifiers, and story non-goals.
- Bazel built `//packages/shared-types:contracts_v1`.
