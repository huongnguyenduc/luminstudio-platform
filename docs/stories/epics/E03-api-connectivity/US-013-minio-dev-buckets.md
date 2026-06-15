# US-013 MinIO Development Buckets

## Status

implemented

## Lane

normal

## Product Contract

The local development platform provides deterministic MinIO buckets for source
and processed 3D assets before product upload or processing behavior is added.
Bucket creation is idempotent and remains a platform concern.

This story does not add product database schema, upload API behavior, worker
processing, object key policy, external routing, or authorization.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/admin-and-processing.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- The dev Kustomize overlay includes a namespace-local MinIO bucket bootstrap
  workload.
- The bootstrap creates buckets for source GLB assets, optimized GLB assets,
  and 360-degree sprite assets.
- Bucket creation is safe to run repeatedly.
- Verification proves bucket existence and object write/read behavior in an
  isolated K3d cluster.
- Existing Phase 1 platform boundaries remain intact: no product schema, API
  upload endpoint, worker behavior, or external route is introduced.

## Design Notes

- Commands: Kubernetes `Job` runs MinIO `mc` commands against the namespace-local
  `minio` Service.
- Queries: none.
- API: none.
- Tables: none.
- Domain rules: bucket names are platform infrastructure, not product object key
  policy.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-013 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Manifest and script static assertions pass. |
| Integration | Bazel manifest targets build and Kustomize renders the bucket bootstrap job. |
| E2E | Not required; no user-facing product workflow exists in this story. |
| Platform | Isolated K3d verification proves MinIO readiness, job completion, bucket existence, object write/read, and safe repeat execution. |
| Release | Not required for local dev platform story. |

## Harness Delta

None expected.

## Evidence

- `bash scripts/verify-us-013.sh` passed.
- Bazel built `//infra/k8s:dev-manifests`, `//infra/k8s:dev-cluster-config`,
  and `//infra/scripts:dev-cluster`.
- Isolated K3d verification created the `minio-buckets` Job, waited for it to
  complete, and proved the `lumin-source-glb`, `lumin-optimized-glb`, and
  `lumin-360-sprites` buckets exist.
- Verification wrote and read `lumin-source-glb/us-013-source.txt`, deleted and
  recreated the bucket Job, and confirmed the source object still existed after
  repeat execution.
