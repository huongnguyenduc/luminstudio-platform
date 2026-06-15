# US-008 Deploy MinIO In The Dev Cluster

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a persistent MinIO service in the K3d
`dev` namespace so that later API stories have an in-cluster object storage
system to connect to and verify.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The development overlay deploys one MinIO instance from an explicitly
  pinned image and exposes it through a namespace-local Service.
- MinIO credentials are isolated in a dev-only Secret and are not exposed
  through ingress or a host port.
- The workload declares startup and readiness checks and becomes Ready in the
  local K3d cluster.
- MinIO data uses a persistent volume claim, and verification proves a
  written file survives replacement of the storage pod.
- Applying the development overlay repeatedly is idempotent.
- The story does not add buckets, Meilisearch, application connectivity,
  external routing, or product behavior.

## Design Notes

- Commands: `infra/scripts/dev-cluster.sh up` and
  `bash scripts/verify-us-008.sh`.
- Queries: Kubernetes rollout, PVC binding, Service endpoints,
  and a persistence probe executed from inside the cluster using `mc`.
- API: none.
- Buckets: a verifier-owned temporary bucket only; no product buckets.
- Domain rules: none; MinIO is platform infrastructure in this story.
- UI surfaces: none.
- Platform: one MinIO StatefulSet with a 1 Gi `ReadWriteOnce` claim. The
  checked-in credential is explicitly local-development-only.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Static assertions check the pinned image, Secret reference, port, probes, PVC, and scope exclusions. |
| Integration | Kustomize renders the MinIO resources and Bazel tracks the manifest inputs. |
| E2E | Not applicable; no product workflow exists. |
| Platform | An isolated K3d cluster reports MinIO Ready, binds its PVC, answers through its Service, and retains a verifier-written value after pod replacement. |
| Release | Deferred until API connectivity and external routing stories exist. |

## Harness Delta

- Add a mechanical story verification command.
- Keep historical infrastructure verifiers scoped to their durable contracts
  as later workloads are added to the shared overlay.

## Evidence

- `kubectl kustomize infra/k8s/overlays/dev`: pass; rendered a MinIO
  Secret, namespace-local Service, pinned StatefulSet image, startup/readiness
  probes, and a 1 Gi `ReadWriteOnce` volume claim without deferred services or
  external routing.
- `bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster`: pass.
- `bash scripts/verify-us-008.sh`: pass; isolated cluster apply was idempotent,
  MinIO reached Ready, its PVC bound, its Service resolved, and a file
  written before pod deletion remained readable from the replacement pod.
- `bash scripts/verify-us-004.sh`, `bash scripts/verify-us-006.sh`, and `bash scripts/verify-us-007.sh`: pass after
  the shared development overlay gained MinIO.
- `infra/scripts/dev-cluster.sh apply`: pass against `lumin-dev`.
  StatefulSet `minio` reached `1/1` Ready, PVC `data-minio-0` was `Bound`,
  and the namespace-local Service exposed EndpointSlice ports 9000 and 9001.
