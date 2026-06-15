#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cluster_name="${LUMIN_CLUSTER_NAME:-lumin-dev}"
cluster_context="k3d-${cluster_name}"
cluster_config="$repo_root/infra/k8s/k3d/dev.yaml"
dev_overlay="$repo_root/infra/k8s/overlays/dev"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required for the development cluster lifecycle" >&2
    exit 1
  fi
}

cluster_exists() {
  k3d cluster list --no-headers | awk -v name="$cluster_name" '$1 == name { found = 1 } END { exit !found }'
}

require_cluster() {
  if ! cluster_exists; then
    echo "K3d cluster '$cluster_name' does not exist; run '$0 create' first" >&2
    exit 1
  fi
}

create_cluster() {
  require_command docker
  docker info >/dev/null

  if cluster_exists; then
    echo "K3d cluster '$cluster_name' already exists"
  else
    k3d cluster create "$cluster_name" --config "$cluster_config"
  fi

  kubectl --context "$cluster_context" wait \
    --for=condition=Ready nodes --all --timeout=120s
}

apply_overlay() {
  require_cluster
  kubectl --context "$cluster_context" apply -k "$dev_overlay"
  kubectl --context "$cluster_context" get namespace dev >/dev/null
}

show_status() {
  require_cluster
  kubectl --context "$cluster_context" get nodes
  kubectl --context "$cluster_context" get namespace dev \
    -o custom-columns='NAME:.metadata.name,ENVIRONMENT:.metadata.labels.lumin\.studio/environment,MANAGED-BY:.metadata.labels.app\.kubernetes\.io/managed-by'
}

delete_cluster() {
  if cluster_exists; then
    k3d cluster delete "$cluster_name"
  else
    echo "K3d cluster '$cluster_name' is already absent"
  fi
}

require_command k3d
require_command kubectl

case "${1:-}" in
  create)
    create_cluster
    ;;
  apply)
    apply_overlay
    ;;
  up)
    create_cluster
    apply_overlay
    show_status
    ;;
  status)
    show_status
    ;;
  delete)
    delete_cluster
    ;;
  *)
    echo "Usage: $0 {create|apply|up|status|delete}" >&2
    exit 2
    ;;
esac
