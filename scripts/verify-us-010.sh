#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker jq k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-010" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n \
  infra/scripts/dev-cluster.sh \
  infra/scripts/import-api-image.sh \
  scripts/verify-us-010.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
api_manifests="$(cat \
  infra/k8s/base/api-gateway-deployment.yaml \
  infra/k8s/base/api-gateway-service.yaml)"

grep -q '^kind: Deployment$' <<<"$rendered"
grep -q '^  name: api-gateway$' <<<"$rendered"
grep -q 'image: lumin/api-gateway:dev$' <<<"$rendered"
grep -q 'imagePullPolicy: Never$' <<<"$api_manifests"
grep -q 'containerPort: 8080$' <<<"$api_manifests"
grep -q 'path: /healthz$' <<<"$api_manifests"
grep -q 'runAsNonRoot: true$' <<<"$api_manifests"
grep -q 'readOnlyRootFilesystem: true$' <<<"$api_manifests"
grep -q 'allowPrivilegeEscalation: false$' <<<"$api_manifests"
grep -q 'type: ClusterIP$' <<<"$api_manifests"

if grep -Eqi 'ingress|postgres|minio|nats|meilisearch|product' <<<"$api_manifests"; then
  echo "US-010 must not add external routing or platform connectivity" >&2
  exit 1
fi

(
  cd services/api-gateway
  go test ./...
)
bazelisk test //services/api-gateway/...
bazelisk build \
  //services/api-gateway:api-gateway-image-amd64 \
  //services/api-gateway:api-gateway-image-arm64 \
  //infra/k8s:dev-manifests \
  //infra/k8s:dev-cluster-config \
  //infra/scripts:dev-cluster \
  //infra/scripts:import-api-image

verify_cluster="lumin-api-verify-$$"
context="k3d-${verify_cluster}"
client_pod="api-health-client"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh create
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/import-api-image.sh
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status deployment/api-gateway --timeout=300s
test "$(kubectl --context "$context" -n dev get deployment api-gateway -o jsonpath='{.status.readyReplicas}')" = "1"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=api-gateway -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

kubectl --context "$context" -n dev run "$client_pod" \
  --image=docker.io/curlimages/curl:8.12.1 \
  --restart=Never \
  --command -- sleep 3600
kubectl --context "$context" -n dev wait --for=condition=Ready "pod/${client_pod}" --timeout=180s
health_response="$(kubectl --context "$context" -n dev exec "$client_pod" -- \
  curl -fsS --retry 30 --retry-all-errors --retry-delay 2 \
  http://api-gateway:8080/healthz)"
test "$(jq -r '.status' <<<"$health_response")" = "ok"

echo "US-010 verification passed"
