# US-010 Deploy The Go API In The Dev Cluster

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need the existing Go API packaged as a Bazel-built
OCI image and deployed in the K3d `dev` namespace so later connectivity stories
can add platform clients behind a verified application runtime boundary.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Bazel cross-compiles the existing API for Linux amd64 and arm64 and packages
  each binary as an OCI image without introducing a parallel Dockerfile build.
- The development overlay deploys one API replica from the locally imported
  image and exposes port 8080 through a namespace-local Service.
- Startup, readiness, and liveness probes call the existing `GET /healthz`
  endpoint, and the workload runs as a non-root user with a read-only root
  filesystem and dropped Linux capabilities.
- Verification imports the image matching the Docker host architecture into an
  isolated K3d cluster, proves rollout readiness and Service discovery, and
  receives the existing health response from inside the cluster.
- Applying the development overlay repeatedly is idempotent.
- The story does not add external routing, product endpoints, persistence,
  object storage, search, NATS connectivity, or shared event contracts.

## Design Notes

- Commands: `infra/scripts/import-api-image.sh` and
  `bash scripts/verify-us-010.sh`.
- Queries: Kubernetes rollout, pod readiness, EndpointSlice discovery, and
  in-cluster HTTP health response.
- API: existing `GET /healthz` only.
- Tables: none.
- Domain rules: none; this story deploys the existing operational boundary.
- UI surfaces: none.
- Platform: one stateless Deployment and one namespace-local ClusterIP Service.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Existing Go handler and configuration tests pass; static assertions cover image, probes, port, and security context. |
| Integration | Bazel builds both Linux OCI images and Kustomize renders the API Deployment and Service. |
| E2E | Not applicable; no product workflow exists. |
| Platform | The architecture-matched image imports into an isolated K3d cluster, the Deployment becomes Ready, the Service resolves, and an in-cluster request returns HTTP 200 with `status: ok`. |
| Release | Deferred until external API routing and application connectivity exist. |

## Harness Delta

- Add a mechanical story verification command.
- Establish the reusable Bazel OCI packaging boundary for later application
  workloads without claiming repository-wide image or release support.

## Evidence

- Native Go tests and `bazelisk test //services/api-gateway/...`: pass.
- Bazel built Linux amd64 and arm64 OCI images plus the development manifests;
  the architecture-matched load target imported `lumin/api-gateway:dev` into
  Docker without a Dockerfile build.
- `bash scripts/verify-us-010.sh`: pass; an isolated K3d cluster received the
  arm64 image, repeated overlay apply was idempotent, the API Deployment reached
  `1/1` Ready, its EndpointSlice resolved, and an in-cluster request returned
  `{"status":"ok"}`.
- `infra/scripts/dev-cluster.sh apply`: pass against `lumin-dev`; Deployment
  `api-gateway` reached `1/1` Ready and its EndpointSlice exposed port 8080.
- `bash scripts/verify-us-004.sh`: pass after the shared development overlay
  gained the API workload.
