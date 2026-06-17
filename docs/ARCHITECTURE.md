# Architecture

## Current Shape

Lumin Studio is a multi-language, event-driven monorepo with these surfaces:

- React + Vite admin browser application.
- Flutter customer mobile application using BLoC and Clean Architecture.
- Go API gateway for synchronous business behavior and relational state.
- Rust worker using reviewed Rust crates for asynchronous 3D processing.
- K3d dev platform with PostgreSQL, MinIO, NATS, Meilisearch, and Traefik.

Bazel is the top-level build graph and Bzlmod is the dependency model. Phase 0
creates package boundaries; Phase 1 introduces executable language rules and
platform resources.

## Dependency Direction

```text
domain
  <- application
      <- infrastructure
          <- interface
              <- app surface
```

Inner layers must not depend on outer layers.

| Layer | May depend on | Must not depend on |
| --- | --- | --- |
| domain | tiny pure utilities | frameworks, database, UI, providers, process/env |
| application | domain and ports | concrete database/provider clients or UI |
| infrastructure | domain and application ports | controllers or UI state |
| interface | application use cases and infrastructure composition | mobile/web state assumptions |
| app surfaces | versioned API/client contracts | backend domain internals |

## Service Boundaries

- `services/api-gateway` owns HTTP/gRPC boundaries, business mutations,
  PostgreSQL state, signed/object access coordination, and event publication.
- `services/worker-3d` owns CPU-heavy mesh and rendering work. It writes output
  objects and publishes completion; it does not mutate relational state.
- `apps/web-admin` and `apps/mobile-flutter` use API contracts and never connect
  directly to PostgreSQL, MinIO, NATS, or Meilisearch.
- `packages/shared-types` owns versioned API, event, and portable schema
  definitions. Generated code belongs to consumers, not the contract source.
- `infra/k8s` owns deployable platform configuration; application packages must
  not embed cluster-specific endpoints.

## Command And Query Boundary

- Commands mutate state and own event/audit side effects.
- Queries read state and format results for consumers.
- Search is a derived read model; PostgreSQL remains authoritative.
- Event consumers must be idempotent because NATS delivery may repeat work.

## Parse-First Rule

Unknown input must be parsed at component boundaries before entering inner
code. This includes HTTP data, environment variables, database rows, NATS
events, MinIO metadata, GLB configuration, deep links, and platform messages.

```text
unknown input
  -> parser/schema validation
  -> typed DTO or command/event
  -> application use case
  -> domain value/entity
```

## Observability Contract

Server and worker operations should emit structured logs containing timestamp,
level, request or trace identity, action, duration, outcome/status, and message.
NATS events must propagate correlation identifiers so API, worker, storage, and
search activity can be traced as one workflow.

Audit records, when introduced, are product data. Operational logs and traces
must not be used as a substitute for audit history.

## Open Architecture Decisions

- Go web framework and persistence library.
- Shared contract format and compatibility policy.
- Bazel rules/toolchain versions for each language.
- 360-degree headless renderer.
- Flutter 3D viewer and bridge strategy.
- Retry, dead-letter, and idempotency policies for event workflows.
