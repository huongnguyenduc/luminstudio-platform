#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker jq k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-009" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n infra/scripts/dev-cluster.sh scripts/verify-us-009.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"
meilisearch_manifests="$(cat \
  infra/k8s/base/meilisearch-secret.yaml \
  infra/k8s/base/meilisearch-service.yaml \
  infra/k8s/base/meilisearch-statefulset.yaml)"

grep -q '^kind: StatefulSet$' <<<"$rendered"
grep -q '^  name: meilisearch$' <<<"$rendered"
grep -q 'image: docker.io/getmeili/meilisearch:v1.46.0$' <<<"$rendered"
grep -q 'containerPort: 7700$' <<<"$rendered"
grep -q 'type: ClusterIP$' <<<"$meilisearch_manifests"
grep -q 'secretRef:$' <<<"$meilisearch_manifests"
grep -q 'name: MEILI_NO_ANALYTICS$' <<<"$meilisearch_manifests"
grep -q 'path: /health$' <<<"$meilisearch_manifests"
grep -q '^  volumeClaimTemplates:$' <<<"$rendered"
grep -q 'ReadWriteOnce$' <<<"$meilisearch_manifests"
grep -q 'storage: 1Gi$' <<<"$rendered"
grep -q '^kind: Secret$' <<<"$rendered"

if grep -Eqi 'ingress|product(s)?(_|-)index|product\.updated' <<<"$meilisearch_manifests"; then
  echo "US-009 must not add external routing or product search behavior" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-meilisearch-verify-$$"
context="k3d-${verify_cluster}"
client_pod="meilisearch-client"
master_key="harness_meilisearch_development_key"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

meili_request() {
  kubectl --context "$context" -n dev exec "$client_pod" -- \
    curl -fsS -H "Authorization: Bearer ${master_key}" "$@"
}

await_task() {
  local task_uid="$1"
  local response status

  for _ in $(seq 1 60); do
    response="$(meili_request "http://meilisearch:7700/tasks/${task_uid}")"
    status="$(jq -r '.status' <<<"$response")"
    case "$status" in
      succeeded)
        return 0
        ;;
      failed | canceled)
        echo "Meilisearch task ${task_uid} ended with status ${status}: ${response}" >&2
        return 1
        ;;
    esac
    sleep 2
  done

  echo "Timed out waiting for Meilisearch task ${task_uid}" >&2
  return 1
}

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/meilisearch --timeout=300s
test "$(kubectl --context "$context" -n dev get statefulset meilisearch -o jsonpath='{.status.readyReplicas}')" = "1"
test "$(kubectl --context "$context" -n dev get pvc data-meilisearch-0 -o jsonpath='{.status.phase}')" = "Bound"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=meilisearch -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

kubectl --context "$context" -n dev run "$client_pod" \
  --image=docker.io/curlimages/curl:8.12.1 \
  --restart=Never \
  --command -- sleep 3600
kubectl --context "$context" -n dev wait --for=condition=Ready "pod/${client_pod}" --timeout=180s
test "$(meili_request http://meilisearch:7700/health | jq -r '.status')" = "available"

index_response="$(meili_request \
  -X POST \
  -H 'Content-Type: application/json' \
  --data '{"uid":"harness_persistence","primaryKey":"id"}' \
  http://meilisearch:7700/indexes)"
await_task "$(jq -er '.taskUid' <<<"$index_response")"

document_response="$(meili_request \
  -X POST \
  -H 'Content-Type: application/json' \
  --data '[{"id":1,"name":"survived"}]' \
  http://meilisearch:7700/indexes/harness_persistence/documents)"
await_task "$(jq -er '.taskUid' <<<"$document_response")"

old_pod_uid="$(kubectl --context "$context" -n dev get pod meilisearch-0 -o jsonpath='{.metadata.uid}')"
kubectl --context "$context" -n dev delete pod meilisearch-0 --wait=true
kubectl --context "$context" -n dev rollout status statefulset/meilisearch --timeout=300s
new_pod_uid="$(kubectl --context "$context" -n dev get pod meilisearch-0 -o jsonpath='{.metadata.uid}')"
test "$old_pod_uid" != "$new_pod_uid"

persisted_document="$(meili_request \
  http://meilisearch:7700/indexes/harness_persistence/documents/1)"
test "$(jq -r '.name' <<<"$persisted_document")" = "survived"

echo "US-009 verification passed"
