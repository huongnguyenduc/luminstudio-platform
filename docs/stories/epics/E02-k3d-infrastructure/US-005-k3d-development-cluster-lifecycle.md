# US-005 Create The K3d Development Cluster Lifecycle

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a repeatable local K3d cluster lifecycle so
that the existing development overlay can be applied and verified against a
real Kubernetes API before platform services are introduced.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- A pinned K3d configuration creates one local cluster named `lumin-dev`.
- Create and delete operations are idempotent and fail clearly when required
  tools or Docker are unavailable.
- The lifecycle does not switch the developer's current Kubernetes context.
- The existing development overlay can be applied repeatedly to the named
  cluster and produces the labeled `dev` namespace.
- Verification uses an isolated temporary cluster and removes it afterward.
- The story does not add PostgreSQL, MinIO, NATS, Meilisearch, application
  workloads, persistence, or product behavior.

## Design Notes

- Commands: `infra/scripts/dev-cluster.sh {create|apply|up|status|delete}` and
  `bash scripts/verify-us-005.sh`.
- Queries: Kubernetes node and namespace readiness only.
- API: none.
- Tables: none.
- Domain rules: none; this story creates the local cluster lifecycle.
- UI surfaces: none.
- Platform: K3d 5.9.0 with pinned K3s `v1.35.5-k3s1`.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Shell syntax and static config assertions pass. |
| Integration | Create and apply operations succeed twice against an isolated cluster. |
| E2E | Not applicable; no product workflow exists. |
| Platform | A ready K3s node and labeled `dev` namespace are observed, then the verification cluster is deleted. |
| Release | Deferred until platform services and application workloads exist. |

## Harness Delta

- Registered the installed `k3d` binary as a `cluster-runtime` provider.
- Added a mechanical story verification command.

## Evidence

- `bash -n infra/scripts/dev-cluster.sh scripts/verify-us-005.sh`: pass.
- `bazelisk build //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster`:
  pass.
- `bash scripts/verify-us-005.sh`: pass; isolated cluster creation and overlay
  application were idempotent, the node became Ready, namespace labels matched,
  and cleanup removed the verification cluster.
- `infra/scripts/dev-cluster.sh up`: pass; cluster `lumin-dev` runs one Ready
  K3s `v1.35.5+k3s1` server and contains the labeled `dev` namespace.
- `kubectl config current-context`: remained `k3d-luminstudio`, proving cluster
  creation did not switch the developer's active context.
