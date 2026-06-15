#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

pnpm install --frozen-lockfile
pnpm --dir apps/web-admin test
pnpm --dir apps/web-admin build
bazelisk test //apps/web-admin/...
bazelisk build //apps/web-admin:web-admin

test -f bazel-bin/apps/web-admin/dist/index.html
grep -q "Lumin Studio Admin" bazel-bin/apps/web-admin/dist/index.html
