#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required to render the development overlay" >&2
  exit 1
fi

rendered="$(kubectl kustomize infra/k8s/overlays/dev)"

test "$(grep -c '^kind: Namespace$' <<<"$rendered")" -eq 1
grep -q '^  name: dev$' <<<"$rendered"
grep -q '^    app.kubernetes.io/managed-by: kustomize$' <<<"$rendered"
grep -q '^    app.kubernetes.io/part-of: lumin-studio$' <<<"$rendered"
grep -q '^    lumin.studio/environment: dev$' <<<"$rendered"

bazelisk build //infra/k8s:dev-manifests

echo "US-004 verification passed"
