#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker jq k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-011" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n scripts/verify-us-011.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
api_manifest="$(cat infra/k8s/base/api-gateway-deployment.yaml)"
for name in POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD DATABASE_URL MINIO_URL MINIO_ACCESS_KEY MINIO_SECRET_KEY NATS_URL MEILISEARCH_URL MEILISEARCH_API_KEY DEPENDENCY_CHECK_TIMEOUT; do
  grep -q "name: ${name}$" <<<"$api_manifest"
done
grep -q 'path: /healthz$' <<<"$api_manifest"
grep -q 'path: /readyz$' <<<"$api_manifest"
grep -q 'postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@postgres:5432/$(POSTGRES_DB)?sslmode=disable$' <<<"$api_manifest"
grep -q 'value: http://minio:9000$' <<<"$api_manifest"
grep -q 'value: nats://nats:4222$' <<<"$api_manifest"
grep -q 'value: http://meilisearch:7700$' <<<"$api_manifest"
grep -q '^kind: Deployment$' <<<"$rendered"

(
  cd services/api-gateway
  go test ./...
)
bazelisk test //services/api-gateway/...
bazelisk build \
  //services/api-gateway:api-gateway-image-amd64 \
  //services/api-gateway:api-gateway-image-arm64 \
  //infra/k8s:dev-manifests

verify_cluster="lumin-connectivity-verify-$$"
context="k3d-${verify_cluster}"
client_pod="api-readiness-client"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh create
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/import-api-image.sh
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/postgres --timeout=300s
kubectl --context "$context" -n dev rollout status statefulset/minio --timeout=300s
kubectl --context "$context" -n dev rollout status deployment/nats --timeout=300s
kubectl --context "$context" -n dev rollout status statefulset/meilisearch --timeout=300s
kubectl --context "$context" -n dev rollout status deployment/api-gateway --timeout=300s

kubectl --context "$context" -n dev run "$client_pod" \
  --image=docker.io/curlimages/curl:8.12.1 \
  --restart=Never \
  --command -- sleep 3600
kubectl --context "$context" -n dev wait --for=condition=Ready "pod/${client_pod}" --timeout=180s

ready_response="$(kubectl --context "$context" -n dev exec "$client_pod" -- \
  curl -fsS http://api-gateway:8080/readyz)"
test "$(jq -r '.status' <<<"$ready_response")" = "ready"

kubectl --context "$context" -n dev scale deployment/nats --replicas=0
kubectl --context "$context" -n dev rollout status deployment/nats --timeout=120s

for _ in $(seq 1 30); do
  ready_replicas="$(kubectl --context "$context" -n dev get deployment api-gateway -o jsonpath='{.status.readyReplicas}')"
  if [[ -z "$ready_replicas" || "$ready_replicas" = "0" ]]; then
    break
  fi
  sleep 2
done
test -z "${ready_replicas:-}" || test "$ready_replicas" = "0"

unready_response="$(kubectl --context "$context" -n dev exec "$client_pod" -- \
  curl -sS -o - -w '\n%{http_code}' "http://$(kubectl --context "$context" -n dev get pod \
    -l app.kubernetes.io/name=api-gateway -o jsonpath='{.items[0].status.podIP}'):8080/readyz")"
test "$(tail -n 1 <<<"$unready_response")" = "503"
test "$(jq -r '.status' <<<"$(sed '$d' <<<"$unready_response")")" = "unavailable"

kubectl --context "$context" -n dev scale deployment/nats --replicas=1
kubectl --context "$context" -n dev rollout status deployment/nats --timeout=180s
kubectl --context "$context" -n dev rollout status deployment/api-gateway --timeout=180s

echo "US-011 verification passed"
