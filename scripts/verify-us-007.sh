#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-007" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n infra/scripts/dev-cluster.sh scripts/verify-us-007.sh

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"

grep -q '^kind: StatefulSet$' <<<"$rendered"
grep -q '^  name: postgres$' <<<"$rendered"
grep -q 'image: docker.io/library/postgres:17.5-alpine$' <<<"$rendered"
grep -q 'containerPort: 5432$' <<<"$rendered"
grep -q 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"$' <<<"$rendered"
grep -q '^  volumeClaimTemplates:$' <<<"$rendered"
grep -q 'storage: 1Gi$' <<<"$rendered"
grep -q '^kind: Secret$' <<<"$rendered"

if grep -Eqi 'minio|meilisearch|ingress' <<<"$rendered"; then
  echo "US-007 must not add deferred services or external routing" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-manifests //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

verify_cluster="lumin-postgres-verify-$$"
context="k3d-${verify_cluster}"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh up
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/postgres --timeout=240s
test "$(kubectl --context "$context" -n dev get statefulset postgres -o jsonpath='{.status.readyReplicas}')" = "1"
test "$(kubectl --context "$context" -n dev get pvc data-postgres-0 -o jsonpath='{.status.phase}')" = "Bound"
test -n "$(kubectl --context "$context" -n dev get endpointslice \
  -l kubernetes.io/service-name=postgres -o jsonpath='{.items[0].endpoints[0].addresses[0]}')"

printf "%s\n" \
  "CREATE TABLE harness_persistence (value text NOT NULL); INSERT INTO harness_persistence VALUES ('survived');" \
  | kubectl --context "$context" -n dev exec -i postgres-0 -- sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1'

old_pod_uid="$(kubectl --context "$context" -n dev get pod postgres-0 -o jsonpath='{.metadata.uid}')"
kubectl --context "$context" -n dev delete pod postgres-0 --wait=true
kubectl --context "$context" -n dev rollout status statefulset/postgres --timeout=240s
new_pod_uid="$(kubectl --context "$context" -n dev get pod postgres-0 -o jsonpath='{.metadata.uid}')"
test "$old_pod_uid" != "$new_pod_uid"

persisted_value="$(kubectl --context "$context" -n dev exec postgres-0 -- sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT value FROM harness_persistence LIMIT 1"')"
test "$persisted_value" = "survived"

echo "US-007 verification passed"
