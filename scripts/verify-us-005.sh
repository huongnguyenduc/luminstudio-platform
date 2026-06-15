#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk docker k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-005" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n infra/scripts/dev-cluster.sh

grep -q '^apiVersion: k3d.io/v1alpha5$' infra/k8s/k3d/dev.yaml
grep -q '^  name: lumin-dev$' infra/k8s/k3d/dev.yaml
grep -q '^image: docker.io/rancher/k3s:v1.35.5-k3s1$' infra/k8s/k3d/dev.yaml
grep -q '^    switchCurrentContext: false$' infra/k8s/k3d/dev.yaml

verify_cluster="lumin-dev-verify-$$"
original_context="$(kubectl config current-context 2>/dev/null || true)"
cleanup() {
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh create
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh create
test "$(kubectl config current-context 2>/dev/null || true)" = "$original_context"
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh status

context="k3d-${verify_cluster}"
test "$(kubectl --context "$context" get namespace dev -o jsonpath='{.metadata.name}')" = "dev"
test "$(kubectl --context "$context" get namespace dev -o jsonpath='{.metadata.labels.lumin\.studio/environment}')" = "dev"
test "$(kubectl --context "$context" get namespace dev -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}')" = "kustomize"

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete
if k3d cluster list --no-headers | awk -v name="$verify_cluster" '$1 == name { found = 1 } END { exit !found }'; then
  echo "Verification cluster '$verify_cluster' still exists after delete" >&2
  exit 1
fi

bazelisk build //infra/k8s:dev-cluster-config //infra/scripts:dev-cluster

echo "US-005 verification passed"
