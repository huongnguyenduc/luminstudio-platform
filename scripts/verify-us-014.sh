#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk curl docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-014" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n scripts/verify-us-014.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
route_manifests="$(cat infra/k8s/base/minio-console-ingress.yaml infra/k8s/base/meilisearch-ingress.yaml)"

test "$(grep -c '^kind: Ingress$' <<<"$route_manifests")" -eq 2
grep -q '^  name: minio-console$' <<<"$route_manifests"
grep -q '^  name: meilisearch$' <<<"$route_manifests"
grep -q 'ingressClassName: traefik$' <<<"$route_manifests"
grep -q 'host: minio-dev.local$' <<<"$route_manifests"
grep -q 'host: search-dev.local$' <<<"$route_manifests"
grep -q 'name: console$' <<<"$route_manifests"
grep -q 'name: http$' <<<"$route_manifests"
grep -q '^kind: Ingress$' <<<"$rendered"

if grep -Eqi 'product\.updated|3d\.task|CREATE TABLE|/upload|authorization|auth|api-gateway' <<<"$route_manifests"; then
  echo "US-014 must not add product events, schema, upload API, auth behavior, or API routing" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-dev-routes-verify-$$"
context="k3d-${verify_cluster}"
local_port="$((20000 + ($$ % 20000)))"
port_forward_log="$(mktemp)"
port_forward_pid=""

cleanup() {
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
    wait "$port_forward_pid" >/dev/null 2>&1 || true
  fi
  rm -f "$port_forward_log"
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/minio --timeout=300s
kubectl --context "$context" -n dev rollout status statefulset/meilisearch --timeout=300s
kubectl --context "$context" -n dev wait job/minio-buckets --for=condition=Complete --timeout=180s
kubectl --context "$context" -n dev get ingress minio-console meilisearch
test "$(kubectl --context "$context" -n dev get ingress minio-console -o jsonpath='{.spec.rules[0].host}')" = "minio-dev.local"
test "$(kubectl --context "$context" -n dev get ingress meilisearch -o jsonpath='{.spec.rules[0].host}')" = "search-dev.local"

kubectl --context "$context" -n kube-system rollout status deployment/traefik --timeout=300s
kubectl --context "$context" -n kube-system port-forward svc/traefik "${local_port}:80" >"$port_forward_log" 2>&1 &
port_forward_pid="$!"

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${local_port}/" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$port_forward_pid" >/dev/null 2>&1; then
    cat "$port_forward_log" >&2
    exit 1
  fi
  sleep 1
done

meili_health="$(curl -fsS -H 'Host: search-dev.local' "http://127.0.0.1:${local_port}/health")"
grep -q '"status":"available"' <<<"$meili_health"

minio_status="$(curl -sS -o /tmp/us-014-minio-route-response -w '%{http_code}' \
  -H 'Host: minio-dev.local' "http://127.0.0.1:${local_port}/")"
case "$minio_status" in
  200 | 301 | 302 | 307 | 308 | 401 | 403)
    ;;
  *)
    cat /tmp/us-014-minio-route-response >&2
    echo "unexpected MinIO console route status ${minio_status}" >&2
    exit 1
    ;;
esac
rm -f /tmp/us-014-minio-route-response

echo "US-014 verification passed"
