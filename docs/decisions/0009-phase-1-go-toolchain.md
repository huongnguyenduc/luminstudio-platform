# 0009 Pin The First Phase 1 Go Toolchain

Date: 2026-06-15

## Status

Accepted

## Context

Phase 0 established Bzlmod package boundaries but deliberately deferred
language rules and executable targets. Phase 1 needs a reproducible first
component build before service integrations or domain behavior are introduced.

## Decision

Pin Bazel 9.1.1 in `.bazelversion`, `rules_go` 0.61.1 in `MODULE.bazel`, and
the downloaded Go 1.26.4 SDK for Bazel builds. The API gateway retains its
native `go.mod`, while Bazel owns the repository-level build and test target.

The first executable target is a dependency-free Go HTTP service with
`GET /healthz`. Framework selection, persistence, messaging, object storage,
search integration, and product APIs remain separate stories.

## Alternatives Considered

1. Use the host Go SDK. Rejected because developer machines currently carry
   different Go versions and Phase 1 requires reproducible builds.
2. Select Fiber or Gin now. Rejected because the health endpoint needs only the
   standard library and does not justify locking the product API framework.
3. Introduce all language toolchains together. Rejected because it increases
   the story blast radius and weakens failure attribution.

## Consequences

- Bazelisk can resolve one checked-in Bazel version for local and CI builds.
- Native Go and Bazel tests exercise the same source package.
- Later Phase 1 stories can add Rust, JavaScript, and Flutter independently.
- The Go SDK download adds a network dependency on the first uncached build.

## Follow-Up

- Add executable Rust worker and web admin targets in separate E01 stories.
- Add K3d services under E02.
- Add PostgreSQL, MinIO, NATS, and Meilisearch connectivity under E03.
