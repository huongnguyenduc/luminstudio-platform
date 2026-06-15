#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-008" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n infra/scripts/dev-cluster.sh scripts/verify-us-008.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
minio_manifests="$(cat infra/k8s/base/minio-secret.yaml infra/k8s/base/minio-service.yaml infra/k8s/base/minio-statefulset.yaml)"

grep -q '^kind: StatefulSet$' <<<"$rendered"
grep -q '^  name: minio$' <<<"$rendered"
grep -q 'image: docker.io/minio/minio:RELEASE.2024-08-03T04-33-23Z$' <<<"$rendered"
grep -q 'containerPort: 9000$' <<<"$rendered"
grep -q 'containerPort: 9001$' <<<"$rendered"
grep -q 'type: ClusterIP$' <<<"$minio_manifests"
grep -q 'secretRef:$' <<<"$minio_manifests"
grep -q 'path: /minio/health/live$' <<<"$minio_manifests"
grep -q 'path: /minio/health/ready$' <<<"$minio_manifests"
grep -q '^  volumeClaimTemplates:$' <<<"$rendered"
grep -q 'ReadWriteOnce$' <<<"$minio_manifests"
grep -q 'storage: 1Gi$' <<<"$rendered"
grep -q '^kind: Secret$' <<<"$rendered"

if grep -Eqi 'meilisearch|ingress' <<<"$minio_manifests"; then
  echo "US-008 must not add deferred services or external routing" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-minio-verify-$$"
context="k3d-${verify_cluster}"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/minio --timeout=240s
test "$(kubectl --context "$context" -n dev get statefulset minio -o jsonpath='{.status.readyReplicas}')" = "1"
test "$(kubectl --context "$context" -n dev get pvc data-minio-0 -o jsonpath='{.status.phase}')" = "Bound"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=minio -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

# Create a bucket, write a file
kubectl --context "$context" -n dev exec minio-0 -- mc alias set myminio http://localhost:9000 harness_minio harness_development_password
kubectl --context "$context" -n dev exec minio-0 -- mc mb myminio/harness-persistence
echo "survived" | kubectl --context "$context" -n dev exec -i minio-0 -- sh -c 'cat > /tmp/test.txt && mc cp /tmp/test.txt myminio/harness-persistence/test.txt'

old_pod_uid="$(kubectl --context "$context" -n dev get pod minio-0 -o jsonpath='{.metadata.uid}')"
kubectl --context "$context" -n dev delete pod minio-0 --wait=true
kubectl --context "$context" -n dev rollout status statefulset/minio --timeout=240s
new_pod_uid="$(kubectl --context "$context" -n dev get pod minio-0 -o jsonpath='{.metadata.uid}')"
test "$old_pod_uid" != "$new_pod_uid"

kubectl --context "$context" -n dev exec minio-0 -- mc alias set myminio http://localhost:9000 harness_minio harness_development_password
persisted_value="$(kubectl --context "$context" -n dev exec minio-0 -- mc cat myminio/harness-persistence/test.txt)"
test "$persisted_value" = "survived"

echo "US-008 verification passed"
