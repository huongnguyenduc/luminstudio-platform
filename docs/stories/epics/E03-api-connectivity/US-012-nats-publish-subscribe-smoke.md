# US-012 NATS Publish Subscribe Smoke

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a repeatable NATS publish/subscribe smoke
command in the K3d `dev` namespace so Phase 1 proves the event bus can carry a
message through its namespace-local Service before product event contracts are
introduced.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Verification starts from the development Kustomize overlay and waits for the
  namespace-local NATS Deployment to become Ready.
- A Kubernetes client pod connects to `nats:4222`, subscribes to one smoke
  subject, publishes one smoke payload, and verifies that the payload is
  delivered back through core NATS pub/sub.
- The smoke proof uses only NATS protocol behavior and does not introduce
  product event schemas, JetStream persistence, worker behavior, API
  publication, or external routes.
- The command is repeatable in an isolated K3d cluster and cleans up the
  cluster after verification.

## Design Notes

- Commands: `bash scripts/verify-us-012.sh`.
- Queries: Kubernetes rollout, Service EndpointSlice, and smoke pod logs.
- API: none.
- Tables: none.
- Domain rules: none; this story proves transport behavior only.
- UI surfaces: none.
- Platform: one core NATS subject under `lumin.us012.smoke`.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Static assertions check the script, NATS Service port, and that no deferred event capabilities are introduced. |
| Integration | Kustomize renders the existing NATS workload and Service; Bazel tracks the manifest inputs. |
| E2E | Not applicable; no product workflow exists. |
| Platform | An isolated K3d deployment receives the smoke payload through NATS publish/subscribe via Service DNS. |
| Release | Deferred until product event contracts and external API routing exist. |

## Harness Delta

- Add a mechanical story verification command for Phase 1 NATS pub/sub proof.

## Evidence

- `bash -n scripts/verify-us-012.sh`: pass.
- `kubectl kustomize infra/k8s/overlays/dev`: pass; rendered the existing
  pinned NATS Deployment and Service with client port `4222`.
- `bash scripts/verify-us-012.sh`: pass; Bazel built the dev manifest and
  cluster script targets, an isolated K3d cluster reached a Ready NATS
  Deployment, the Service had an EndpointSlice address, and a BusyBox client pod
  subscribed to `lumin.us012.smoke`, published `us-012-nats-pubsub-smoke`, and
  received the payload back through core NATS pub/sub.
