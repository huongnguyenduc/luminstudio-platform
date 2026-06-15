#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cluster_name="${LUMIN_CLUSTER_NAME:-lumin-dev}"

for command in bazelisk docker k3d; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to import the API image" >&2
    exit 1
  fi
done

if ! k3d cluster list --no-headers | awk -v name="$cluster_name" \
  '$1 == name { found = 1 } END { exit !found }'; then
  echo "K3d cluster '$cluster_name' does not exist" >&2
  exit 1
fi

case "$(docker info --format '{{.Architecture}}')" in
  amd64 | x86_64)
    image_load_target="//services/api-gateway:api-gateway-image-load-amd64"
    ;;
  arm64 | aarch64)
    image_load_target="//services/api-gateway:api-gateway-image-load-arm64"
    ;;
  *)
    echo "Unsupported Docker architecture: $(docker info --format '{{.Architecture}}')" >&2
    exit 1
    ;;
esac

cd "$repo_root"
bazelisk run "$image_load_target"
k3d image import lumin/api-gateway:dev --cluster "$cluster_name"
