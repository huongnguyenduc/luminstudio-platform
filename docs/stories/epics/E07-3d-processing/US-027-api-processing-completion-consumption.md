# US-027 API Processing Completion Consumption

## Status

implemented

## Lane

normal

## Product Contract

The Go API consumes valid v1 `3d.task.completed` events, stores the optimized
GLB and 360-degree sprite object references on the authoritative product row,
and marks processing as completed.

This story does not package or deploy the worker, prove the live K3d pipeline,
publish a follow-up `product.updated` event, or add retries, outbox semantics,
idempotency keys, failure events, dead-letter handling, authentication, UI, or
mobile behavior.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The API subscribes to `lumin.3d.task.completed` with a dedicated queue group.
- Completion events are decoded strictly and validated against the v1 envelope,
  identity, object reference, and expected processed-asset bucket rules.
- A valid completion atomically stores both processed asset references, sets
  `processing_status` to `completed`, and uses the event occurrence time as the
  product update time.
- A completion older than the current product update cannot overwrite newer
  product state; replaying the same completion remains a stable update.
- Invalid events do not mutate PostgreSQL; store failures are reported without
  terminating the subscription loop.
- Native Go and Bazel tests cover validation, handler handoff, store arguments,
  runtime wiring, and the API binary build.

## Design Notes

- Commands: `bash scripts/verify-us-027.sh`.
- Queries: one PostgreSQL `UPDATE products ... RETURNING` mutation.
- API: no new HTTP route.
- Tables: uses existing `products.optimized_asset`, `products.sprite_asset`,
  `products.processing_status`, and `products.updated_at` columns.
- Events: consumes v1 `3d.task.completed` from
  `lumin.3d.task.completed`.
- Domain rules: both processed assets are persisted in one relational mutation;
  the API remains the only owner of relational state changes.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-027 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go tests cover strict event validation, completion handoff, failure propagation, and processed asset argument encoding. |
| Integration | Native Go and Bazel tests compile the subscriber, product store, and main runtime wiring. |
| E2E | Not required; worker deployment and live event flow remain deferred. |
| Platform | Not required; no K3d workload changes are included. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-027.sh` passed.
- Native Go tests and Bazel API tests passed.
- Bazel built `//services/api-gateway:api-gateway`.
- Static checks confirmed the completion subject, strict handler, atomic store
  mutation, runtime subscriber wiring, product documentation, and non-goals.
