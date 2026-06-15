# US-011 Connect The Go API To Platform Services

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need the Go API to prove connectivity to PostgreSQL,
MinIO, NATS, and Meilisearch so Phase 1 has a verified application boundary for
later product persistence, storage, messaging, and search stories.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The API parses required platform endpoints and credentials from environment
  variables and rejects missing or invalid configuration.
- `GET /healthz` remains an independent liveness endpoint, while `GET /readyz`
  returns ready only when PostgreSQL, MinIO, NATS, and Meilisearch respond.
- The development Deployment receives namespace-local service endpoints and
  existing development credentials through Kubernetes configuration.
- Live verification proves readiness through the API Service and proves that a
  broken dependency makes the API unready before recovery.
- The story does not create product schema, MinIO buckets, Meilisearch indexes,
  shared events, external routes, or product endpoints.

## Design Notes

- Commands: `bash scripts/verify-us-011.sh`.
- Queries: API liveness/readiness and Kubernetes readiness state during a
  controlled dependency outage.
- API: operational `GET /readyz`; no product API contract.
- Tables: none.
- Domain rules: none; this story establishes platform connectivity only.
- UI surfaces: none.
- Platform: PostgreSQL protocol ping, authenticated MinIO bucket listing, NATS
  protocol ping, and authenticated Meilisearch version HTTP.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Configuration parsing and readiness HTTP behavior pass. |
| Integration | Native and Bazel Go tests pass; OCI images and manifests build. |
| E2E | Not applicable; no product workflow exists. |
| Platform | An isolated K3d deployment reports ready with all four dependencies, becomes unready during a controlled NATS outage, and recovers afterward. |
| Release | Deferred until external API routing exists. |

## Harness Delta

- Add a mechanical verifier that proves both the healthy path and dependency
  failure propagation through Kubernetes readiness.

## Evidence

- `go test ./...`: pass for API routes, health handlers, configuration parsing,
  and platform package tests.
- `bazelisk test //services/api-gateway/...`: pass for all three Go test targets.
- Bazel built both Linux OCI images and the development manifest target.
- `bash scripts/verify-us-011.sh`: pass in an isolated K3d cluster; all four
  dependencies and the API became ready, `/readyz` returned `ready`, scaling
  NATS to zero removed API readiness and returned HTTP 503 from the API pod,
  and restoring NATS returned the deployment to Ready.
