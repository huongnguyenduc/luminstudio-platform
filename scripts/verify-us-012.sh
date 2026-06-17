#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-012" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n scripts/verify-us-012.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
nats_manifests="$(cat infra/k8s/base/nats-deployment.yaml infra/k8s/base/nats-service.yaml)"

grep -q '^  name: nats$' <<<"$rendered"
grep -q 'image: docker.io/library/nats:2.11.6-alpine$' <<<"$rendered"
grep -q 'containerPort: 4222$' <<<"$rendered"
grep -q 'port: 4222$' <<<"$rendered"

if grep -Eqi 'jetstream|stream|consumer|3d\\.task|product\\.updated' <<<"$nats_manifests"; then
  echo "US-012 must not introduce durable streams or product event contracts" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-nats-pubsub-verify-$$"
context="k3d-${verify_cluster}"
client_pod="nats-pubsub-smoke"
cleanup() {
  kubectl --context "$context" -n dev delete pod "$client_pod" \
    --ignore-not-found --wait=false >/dev/null 2>&1 || true
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status deployment/nats --timeout=180s
test "$(kubectl --context "$context" -n dev get deployment nats -o jsonpath='{.status.readyReplicas}')" = "1"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=nats -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

kubectl --context "$context" -n dev run "$client_pod" \
  --image=docker.io/library/busybox:1.36.1 \
  --restart=Never \
  --command -- sh -c '
    set -eu
    subject="lumin.us012.smoke"
    payload="us-012-nats-pubsub-smoke"
    output="/tmp/nats-smoke.out"
    {
      printf "CONNECT {\"verbose\":false,\"pedantic\":true,\"lang\":\"sh\",\"version\":\"us-012\"}\r\n"
      printf "SUB %s 1\r\n" "$subject"
      printf "PUB %s %s\r\n%s\r\n" "$subject" "${#payload}" "$payload"
      printf "PING\r\n"
      sleep 1
    } | nc -w 5 nats 4222 > "$output"
    cat "$output"
    grep -q "MSG ${subject} 1 ${#payload}" "$output"
    grep -q "$payload" "$output"
  '
kubectl --context "$context" -n dev wait "pod/${client_pod}" \
  --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s

smoke_response="$(kubectl --context "$context" -n dev logs "$client_pod")"
grep -q 'us-012-nats-pubsub-smoke' <<<"$smoke_response"

echo "US-012 verification passed"
