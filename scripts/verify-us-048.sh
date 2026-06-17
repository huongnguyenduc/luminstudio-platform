#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk grep pnpm; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-048" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-048.sh

app_dir="apps/web-admin"
story_file="docs/stories/epics/E04-admin-api/US-048-web-admin-source-glb-upload-api-integration.md"

for required_file in \
  "$app_dir/src/App.tsx" \
  "$app_dir/src/App.css" \
  "$app_dir/src/App.test.tsx" \
  "$app_dir/src/index.css" \
  "$story_file"; do
  test -f "$required_file"
done

app_text="$(cat "$app_dir/src/App.tsx")"
style_text="$(cat "$app_dir/src/App.css" "$app_dir/src/index.css")"
test_text="$(cat "$app_dir/src/App.test.tsx")"
story_text="$(cat "$story_file")"
roadmap_text="$(cat docs/product/roadmap.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"

for required in \
  'export type SourceUploadState' \
  'export function adminSourceUploadUrl' \
  'export async function uploadProductSource' \
  'export function validateSourceUpload' \
  'method: "POST"' \
  'body.append("source", file)' \
  'Accept: "application/json"' \
  'ProductSourceUploadPanel' \
  'sourceUploadState' \
  'Upload GLB' \
  'Uploaded GLB for' \
  'await reloadProducts()'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  'selected-product-grid' \
  'selected-product-card' \
  'upload-card' \
  'source-upload-form' \
  'asset-summary' \
  'form-message-error' \
  'form-message-success' \
  '@media (max-width: 760px)'; do
  grep -q "$required" <<<"$style_text"
done

for required in \
  'builds the source upload route with encoded product identity' \
  'posts a multipart source file to the product source route' \
  'rejects missing files, non-GLB files, and records without mesh config' \
  'renders source asset summary and the upload control' \
  'renders upload progress, success, and failure states inline' \
  'renders the selected product edit workflow'; do
  grep -q "$required" <<<"$test_text"
done

for required in \
  'US-048 Web Admin Source GLB Upload API Integration' \
  'POST /admin/products/{id}/source-glb' \
  'multipart form data with field name `source`' \
  'This story does not add product delete, authentication' \
  'Web Admin remains behind the Go API gateway'; do
  grep -q "$required" <<<"$story_text"
done

grep -q 'US-048 Web Admin Source GLB Upload API Integration' <<<"$roadmap_text"
grep -q 'React Web Admin now uploads source `.glb` files' <<<"$admin_text"
grep -q 'US-048' <<<"$platform_text"
grep -q 'US-048 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-048.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-048.sh' <<<"$app_readme_text"

if grep -R -E -i 'PostgreSQL|MinIO|NATS|Meilisearch|checkout|payment|auth|delete product|signed object URL' \
  "$app_dir/src"; then
  echo "US-048 must not add direct platform access, checkout, payment, auth, delete, or signed URL UI" >&2
  exit 1
fi

pnpm --dir "$app_dir" test
pnpm --dir "$app_dir" build

bazelisk test //apps/web-admin:web-admin-test
bazelisk build //apps/web-admin:web-admin

echo "US-048 verification passed"
