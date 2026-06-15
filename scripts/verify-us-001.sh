#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if command -v bazelisk >/dev/null 2>&1; then
  bazel_command=(bazelisk)
elif command -v bazel >/dev/null 2>&1; then
  bazel_command=(bazel)
elif [[ -x "$(go env GOPATH)/bin/bazelisk" ]]; then
  bazel_command=("$(go env GOPATH)/bin/bazelisk")
else
  echo "US-001 requires Bazelisk or Bazel on PATH." >&2
  exit 1
fi

(
  cd services/api-gateway
  go test ./...
)

"${bazel_command[@]}" test //services/api-gateway/...
"${bazel_command[@]}" build //services/api-gateway:api-gateway
