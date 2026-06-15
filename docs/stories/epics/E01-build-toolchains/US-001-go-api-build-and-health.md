# US-001 Build The Go API And Health Endpoint

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a pinned Bazel and Go toolchain plus one
executable API gateway target so that Phase 1 has real component build and test
proof rather than structural package declarations.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `.bazelversion` pins the selected Bazel LTS patch release.
- Bzlmod declares `rules_go` and a pinned downloaded Go SDK.
- `//services/api-gateway:api-gateway` builds successfully.
- `//services/api-gateway/...` tests successfully.
- `GET /healthz` returns HTTP 200 and `{"status":"ok"}`.
- Invalid `PORT` input is rejected before the server starts.
- No product schema, external service connection, or domain endpoint is added.

## Design Notes

- Commands: `bash scripts/verify-us-001.sh`.
- Queries: none.
- API: `GET /healthz` is an operational smoke endpoint.
- Tables: none.
- Domain rules: none; this story is component bootstrap only.
- UI surfaces: none.
- Build: Bazel 9.1.1, rules_go 0.61.1, Go SDK 1.26.4.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Handler, route, and environment parsing tests pass. |
| Integration | Native Go and Bazel compile/test the API package. |
| E2E | Not applicable; no user-facing workflow exists. |
| Platform | Bazel builds the executable with the pinned downloaded SDK. |
| Release | Deferred until deployable images and K3d resources exist. |

## Harness Delta

- Added migration 005 to restore capability-aware tool registry queries.
- Closed Harness backlog #1 after migration and registry verification passed.

## Evidence

- `go test ./...` from `services/api-gateway`: pass.
- `bazelisk test //services/api-gateway/...`: pass; 2 tests executed.
- `bazelisk build //services/api-gateway:api-gateway`: pass.
- Built binary smoke request to `GET /healthz`: pass with HTTP 200 and
  `{"status":"ok"}`.
