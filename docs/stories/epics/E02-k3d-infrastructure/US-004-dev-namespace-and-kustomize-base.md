# US-004 Create The K3d Dev Namespace And Kustomize Base

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a renderable Kustomize boundary for the local
`dev` namespace so that later Phase 1 service stories share one deployment
entrypoint without claiming that workloads already run.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `infra/k8s/base` is a valid Kustomize base for later shared resources.
- `infra/k8s/overlays/dev` renders exactly one namespace named `dev`.
- Rendered resources carry stable Lumin Studio ownership and environment labels.
- The story does not add PostgreSQL, MinIO, NATS, Meilisearch, application
  workloads, ingress, persistence, or cluster creation behavior.
- A repeatable verifier renders the overlay and builds its Bazel file target.

## Design Notes

- Commands: `bash scripts/verify-us-004.sh`.
- Queries: none.
- API: none.
- Tables: none.
- Domain rules: none; this story creates a deployment boundary only.
- UI surfaces: none.
- Platform: Kustomize output rendered by the locally equipped `kubectl`.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Static assertions check namespace identity, labels, and scope exclusions. |
| Integration | `kubectl kustomize` composes the base and development overlay. |
| E2E | Not applicable; no workload or product workflow exists. |
| Platform | Bazel tracks all development manifest inputs. |
| Release | Deferred until K3d creation and service deployment stories exist. |

## Harness Delta

- Registered the present `kubectl` binary as a `deploy-verification` provider.
- Added a mechanical story verification command.

## Evidence

- `kubectl kustomize infra/k8s/overlays/dev`: pass; rendered one labeled
  `Namespace` named `dev` and no workloads.
- `bazelisk build //infra/k8s:dev-manifests`: pass.
- `bash scripts/verify-us-004.sh`: pass.
