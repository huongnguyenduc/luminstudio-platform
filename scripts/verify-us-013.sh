#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-013" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n scripts/verify-us-013.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
bucket_job="$(cat infra/k8s/base/minio-buckets-job.yaml)"
minio_manifests="$(cat infra/k8s/base/minio-secret.yaml infra/k8s/base/minio-service.yaml infra/k8s/base/minio-statefulset.yaml infra/k8s/base/minio-buckets-job.yaml)"

grep -q '^kind: Job$' <<<"$rendered"
grep -q '^  name: minio-buckets$' <<<"$rendered"
grep -q 'image: docker.io/minio/minio:RELEASE.2024-08-03T04-33-23Z$' <<<"$rendered"
grep -q 'mc mb --ignore-existing dev-minio/lumin-source-glb$' <<<"$bucket_job"
grep -q 'mc mb --ignore-existing dev-minio/lumin-optimized-glb$' <<<"$bucket_job"
grep -q 'mc mb --ignore-existing dev-minio/lumin-360-sprites$' <<<"$bucket_job"
grep -q 'http://minio:9000' <<<"$bucket_job"
grep -q 'secretRef:$' <<<"$bucket_job"
grep -q 'name: minio$' <<<"$bucket_job"

if grep -Eqi 'Ingress|traefik|product\.updated|3d\.task|CREATE TABLE|/upload|authorization|auth' <<<"$minio_manifests"; then
  echo "US-013 must not add external routing, event contracts, product schema, upload API, or auth behavior" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-minio-buckets-verify-$$"
context="k3d-${verify_cluster}"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/minio --timeout=240s
kubectl --context "$context" -n dev wait job/minio-buckets --for=condition=Complete --timeout=180s
test "$(kubectl --context "$context" -n dev get statefulset minio -o jsonpath='{.status.readyReplicas}')" = "1"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=minio -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

kubectl --context "$context" -n dev exec minio-0 -- mc alias set dev-minio http://localhost:9000 harness_minio harness_development_password

for bucket in lumin-source-glb lumin-optimized-glb lumin-360-sprites; do
  kubectl --context "$context" -n dev exec minio-0 -- mc stat "dev-minio/${bucket}"
done

echo "source asset smoke" | kubectl --context "$context" -n dev exec -i minio-0 -- \
  sh -c 'cat > /tmp/us-013-source.txt && mc cp /tmp/us-013-source.txt dev-minio/lumin-source-glb/us-013-source.txt'
source_value="$(kubectl --context "$context" -n dev exec minio-0 -- mc cat dev-minio/lumin-source-glb/us-013-source.txt)"
test "$source_value" = "source asset smoke"

kubectl --context "$context" -n dev delete job minio-buckets --wait=true
kubectl --context "$context" apply -k infra/k8s/overlays/dev
kubectl --context "$context" -n dev wait job/minio-buckets --for=condition=Complete --timeout=180s
source_value_after_repeat="$(kubectl --context "$context" -n dev exec minio-0 -- mc cat dev-minio/lumin-source-glb/us-013-source.txt)"
test "$source_value_after_repeat" = "source asset smoke"

echo "US-013 verification passed"
