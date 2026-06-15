#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cargo test -p worker-3d
bazelisk test //services/worker-3d/...
bazelisk build //services/worker-3d:worker-3d

worker_output="$(WORKER_CONCURRENCY=2 bazel-bin/services/worker-3d/worker-3d)"
expected_output='{"level":"info","component":"worker-3d","status":"ready","concurrency":2}'
test "$worker_output" = "$expected_output"

if WORKER_CONCURRENCY=0 bazel-bin/services/worker-3d/worker-3d >/dev/null 2>&1; then
  echo "worker accepted invalid WORKER_CONCURRENCY" >&2
  exit 1
fi

echo "US-002 verification passed"
