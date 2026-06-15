#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_files=(
  AGENTS.md
  README.md
  SPEC.md
  MODULE.bazel
  BUILD.bazel
  .bazelrc
  Cargo.toml
  docs/product/overview.md
  docs/product/platform-foundation.md
  docs/product/admin-and-processing.md
  docs/product/mobile-commerce.md
  docs/product/roadmap.md
  docs/stories/epics/E00-foundation/US-000-establish-platform-foundation.md
  apps/web-admin/BUILD.bazel
  apps/mobile-flutter/BUILD.bazel
  services/api-gateway/BUILD.bazel
  services/worker-3d/BUILD.bazel
  packages/shared-types/BUILD.bazel
  packages/third-party/BUILD.bazel
  infra/k8s/BUILD.bazel
  infra/scripts/BUILD.bazel
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    printf 'missing required foundation file: %s\n' "$path" >&2
    exit 1
  fi
done

if ! grep -q 'name = "lumin_studio"' MODULE.bazel; then
  printf 'MODULE.bazel does not declare the lumin_studio module\n' >&2
  exit 1
fi

if command -v cargo >/dev/null 2>&1; then
  cargo metadata --no-deps --format-version 1 >/dev/null
fi

if command -v bazelisk >/dev/null 2>&1; then
  bazel_command=(bazelisk)
elif command -v bazel >/dev/null 2>&1; then
  bazel_command=(bazel)
elif command -v go >/dev/null 2>&1 && [[ -x "$(go env GOPATH)/bin/bazelisk" ]]; then
  bazel_command=("$(go env GOPATH)/bin/bazelisk")
else
  bazel_command=()
fi

if (( ${#bazel_command[@]} > 0 )); then
  "${bazel_command[@]}" query //... >/dev/null
  printf 'foundation verification passed; bazel package query passed\n'
else
  printf 'foundation verification passed; bazel package query skipped (Bazelisk/Bazel not installed)\n'
fi
