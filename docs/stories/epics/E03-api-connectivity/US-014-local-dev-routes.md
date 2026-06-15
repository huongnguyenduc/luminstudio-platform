# US-014 Local Development Routes

## Status

implemented

## Lane

normal

## Product Contract

The local development platform exposes MinIO administration and Meilisearch
through Traefik host routes so developers can inspect object storage and search
state without connecting clients directly to platform dependencies.

This story does not add public API routing, product upload behavior, product
search indexes, product event contracts, authentication, authorization, or
production ingress topology.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The dev Kustomize overlay includes a Traefik-backed Ingress for the MinIO
  console at `minio-dev.local`.
- The dev Kustomize overlay includes a Traefik-backed Ingress for Meilisearch
  at `search-dev.local`.
- Verification proves both host routes through Traefik in an isolated K3d
  cluster.
- Existing service boundaries remain intact: browser/mobile clients still use
  the Go API for product behavior, and this story does not expose the Go API or
  add product workflows.

## Design Notes

- Commands: `bash scripts/verify-us-014.sh`.
- Queries: Kubernetes Ingress rendering, rollout status, and host-routed HTTP
  checks through Traefik.
- API: none.
- Tables: none.
- Domain rules: development routes are operational access only.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-014 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Static manifest assertions pass for Ingress hosts, classes, and backend ports. |
| Integration | Bazel manifest targets build and Kustomize renders both Ingress resources. |
| E2E | Not required; no user-facing product workflow exists in this story. |
| Platform | Isolated K3d verification proves Traefik routes `minio-dev.local` to the MinIO console and `search-dev.local` to Meilisearch health. |
| Release | Not required for local dev platform story. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-014.sh` passed.
- Bazel built `//infra/k8s:dev-manifests`, `//infra/k8s:dev-cluster-config`,
  and `//infra/scripts:dev-cluster`.
- Kustomize rendered Traefik Ingress resources for `minio-dev.local` and
  `search-dev.local` in the `dev` namespace.
- Isolated K3d verification applied the dev overlay idempotently, waited for
  MinIO, Meilisearch, MinIO bucket bootstrap, and Traefik readiness, and proved
  host-routed HTTP traffic through Traefik to the MinIO console and Meilisearch
  health endpoint.
