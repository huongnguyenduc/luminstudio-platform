#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cluster_name="${LUMIN_CLUSTER_NAME:-lumin-dev}"

for command in docker k3d; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to import the worker image" >&2
    exit 1
  fi
done

docker info >/dev/null

if ! k3d cluster list --no-headers | awk -v name="$cluster_name" \
  '$1 == name { found = 1 } END { exit !found }'; then
  echo "K3d cluster '$cluster_name' does not exist" >&2
  exit 1
fi

cd "$repo_root"
docker build -f services/worker-3d/Dockerfile -t lumin/worker-3d:dev .
k3d image import lumin/worker-3d:dev --cluster "$cluster_name"
