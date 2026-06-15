# US-006 Deploy NATS In The Dev Cluster

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a healthy NATS service in the K3d `dev`
namespace so that later API and worker stories have an in-cluster event bus to
connect to and verify.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The development overlay deploys one NATS server from an explicitly pinned
  image and exposes it through a namespace-local Kubernetes Service.
- The NATS workload declares startup/readiness health checks against its
  monitoring endpoint and becomes Ready in the local K3d cluster.
- Applying the development overlay repeatedly is idempotent.
- Verification proves NATS health from inside the cluster against the Service,
  not through a host-only shortcut.
- The story does not add PostgreSQL, MinIO, Meilisearch, ingress, persistence,
  application connectivity, shared event contracts, or product behavior.

## Design Notes

- Commands: `infra/scripts/dev-cluster.sh up` and a story verifier added during
  implementation.
- Queries: Kubernetes rollout, pod readiness, Service endpoints, and NATS
  health only.
- API: none.
- Tables: none.
- Domain rules: none; this story adds the first platform workload.
- UI surfaces: none.
- Platform: single-node core NATS for local development; JetStream persistence
  and external routing are deferred until a selected story requires them.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Static assertions check the pinned image, labels, ports, probes, and scope exclusions. |
| Integration | Kustomize renders the NATS workload and Service, and Bazel tracks the manifest inputs. |
| E2E | Not applicable; no product workflow exists. |
| Platform | An isolated K3d cluster reports the NATS rollout Ready and an in-cluster request to the Service health endpoint succeeds. |
| Release | Deferred until API connectivity and publish/subscribe smoke stories exist. |

## Harness Delta

- Add a mechanical story verification command during implementation.
- Register an additional tool only if verification needs a capability not
  already present in the tool registry.

## Evidence

- `kubectl kustomize infra/k8s/overlays/dev`: pass; rendered one NATS
  `Deployment`, one namespace-local `Service`, pinned image, monitoring probes,
  and no deferred platform services or persistence.
- `bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config
  //infra/scripts:dev-cluster`: pass.
- `bash scripts/verify-us-006.sh`: pass; isolated cluster apply was idempotent,
  the NATS rollout reached one Ready replica, an EndpointSlice address existed,
  and an in-cluster curl pod received an `ok` health response through Service
  DNS before the verification cluster was deleted.
- `infra/scripts/dev-cluster.sh apply`: pass against `lumin-dev`; deployment
  `nats` reached `1/1` Ready and Service `nats` exposed ports `4222` and `8222`
  through an EndpointSlice in namespace `dev`.
