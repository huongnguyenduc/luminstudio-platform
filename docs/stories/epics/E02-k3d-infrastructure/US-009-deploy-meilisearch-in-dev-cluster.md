# US-009 Deploy Meilisearch In The Dev Cluster

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a persistent Meilisearch service in the K3d
`dev` namespace so that later API stories have an in-cluster derived search
index to connect to and verify.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The development overlay deploys one Meilisearch instance from an explicitly
  pinned image and exposes it through a namespace-local Service.
- The development master key is isolated in a dev-only Secret, and analytics
  are disabled for the local instance.
- The workload declares startup and readiness checks and becomes Ready in the
  local K3d cluster.
- Meilisearch data uses a persistent volume claim, and verification proves an
  indexed document survives replacement of the search pod.
- Applying the development overlay repeatedly is idempotent.
- The story does not add product indexes, external routing, application
  connectivity, synchronization events, or product behavior.

## Design Notes

- Commands: `infra/scripts/dev-cluster.sh up` and
  `bash scripts/verify-us-009.sh`.
- Queries: Kubernetes rollout, PVC binding, Service endpoints, Meilisearch
  health, task completion, and document retrieval through an in-cluster client.
- API: Meilisearch administrative API is used only by the verifier.
- Indexes: a verifier-owned temporary index only; no product search schema.
- Domain rules: PostgreSQL remains authoritative; this service is a derived
  read-model platform dependency.
- UI surfaces: none; the search dashboard and external route remain deferred.
- Platform: one Meilisearch StatefulSet with a 1 Gi `ReadWriteOnce` claim.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Static assertions check the pinned image, Secret reference, port, probes, analytics setting, PVC, and scope exclusions. |
| Integration | Kustomize renders the Meilisearch resources and Bazel tracks the manifest inputs. |
| E2E | Not applicable; no product workflow exists. |
| Platform | An isolated K3d cluster reports Meilisearch Ready, binds its PVC, answers through its Service, completes indexing, and retains a verifier-written document after pod replacement. |
| Release | Deferred until API connectivity and external routing stories exist. |

## Harness Delta

- Add a mechanical story verification command.
- Keep historical infrastructure verifiers scoped to their durable contracts
  as the shared development overlay gains the final Phase 1 platform service.

## Evidence

- `kubectl kustomize infra/k8s/overlays/dev`: pass; rendered a Meilisearch
  Secret, namespace-local Service, pinned StatefulSet image, disabled analytics,
  health probes, and a 1 Gi `ReadWriteOnce` volume claim without product search
  behavior or external routing.
- `bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster`: pass.
- `bash scripts/verify-us-009.sh`: pass; isolated cluster apply was idempotent,
  Meilisearch reached Ready, its PVC bound, its Service resolved, an indexing
  task completed, and the indexed document remained readable after pod
  replacement.
- `bash scripts/verify-us-004.sh`, `bash scripts/verify-us-006.sh`,
  `bash scripts/verify-us-007.sh`, and `bash scripts/verify-us-008.sh`: pass
  after the shared development overlay gained Meilisearch.
- `infra/scripts/dev-cluster.sh apply`: pass against `lumin-dev`. StatefulSet
  `meilisearch` reached `1/1` Ready, PVC `data-meilisearch-0` was `Bound`, and
  the namespace-local EndpointSlice exposed port 7700.
