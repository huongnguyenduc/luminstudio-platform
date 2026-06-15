#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-006" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n infra/scripts/dev-cluster.sh scripts/verify-us-006.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"

test "$(grep -c '^kind: Deployment$' <<<"$rendered")" -eq 1
test "$(grep -c '^kind: Service$' <<<"$rendered")" -eq 1
grep -q '^  name: nats$' <<<"$rendered"
grep -q 'image: docker.io/library/nats:2.11.6-alpine$' <<<"$rendered"
grep -q 'path: /healthz$' <<<"$rendered"
grep -q 'containerPort: 4222$' <<<"$rendered"
grep -q 'containerPort: 8222$' <<<"$rendered"

if grep -Eqi 'postgres|minio|meilisearch|ingress|persistentvolumeclaim|jetstream' <<<"$rendered"; then
  echo "US-006 must contain only the scoped core NATS workload" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-nats-verify-$$"
cleanup() {
  kubectl --context "k3d-${verify_cluster}" -n dev delete pod nats-health-check \
    --ignore-not-found --wait=false >/dev/null 2>&1 || true
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

context="k3d-${verify_cluster}"
kubectl --context "$context" -n dev rollout status deployment/nats --timeout=180s
test "$(kubectl --context "$context" -n dev get deployment nats -o jsonpath='{.status.readyReplicas}')" = "1"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=nats -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

kubectl --context "$context" -n dev run nats-health-check \
  --image=docker.io/curlimages/curl:8.16.0 \
  --restart=Never \
  --command -- sh -c 'curl --fail --silent --show-error http://nats:8222/healthz'
kubectl --context "$context" -n dev wait pod/nats-health-check \
  --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
health_response="$(kubectl --context "$context" -n dev logs nats-health-check)"
if ! grep -Eq '(^ok$|"status"[[:space:]]*:[[:space:]]*"ok")' <<<"$health_response"; then
  echo "Unexpected NATS health response: $health_response" >&2
  exit 1
fi

echo "US-006 verification passed"
