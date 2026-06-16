#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk grep pnpm; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-047" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-047.sh

app_dir="apps/web-admin"
story_file="docs/stories/epics/E04-admin-api/US-047-web-admin-product-edit-api-integration.md"

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
  'export type ProductEditState' \
  'export function adminProductUrl' \
  'export async function updateAdminProduct' \
  'method: "PUT"' \
  'export function productRecordToFormValues' \
  'ProductEditPanel' \
  'ProductDraftForm' \
  'selectedProductId' \
  'PUT' \
  'Content-Type": "application/json"' \
  'Save changes' \
  'Updated ${editState.productName}.' \
  'await reloadProducts()'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  'edit-panel' \
  'secondary-button' \
  'row-action-button' \
  'product-row-selected' \
  'form-message-error' \
  'form-message-success' \
  'font-variant-numeric: tabular-nums' \
  '@media (max-width: 760px)'; do
  grep -q "$required" <<<"$style_text"
done

for required in \
  'builds the admin product detail route with encoded product identity' \
  'hydrates the product draft form from a product record' \
  'puts the product draft to the admin update route' \
  'renders the selected product edit workflow' \
  'renders success and failure states inline' \
  'renders product rows from v1 product records'; do
  grep -q "$required" <<<"$test_text"
done

for required in \
  'US-047 Web Admin Product Edit API Integration' \
  'PUT /admin/products/{id}' \
  'same client-side validation as product creation' \
  'This story does not add product delete, source GLB upload' \
  'Web Admin clients stay behind the Go API gateway'; do
  grep -q "$required" <<<"$story_text"
done

grep -q 'US-047 Web Admin Product Edit API Integration' <<<"$roadmap_text"
grep -q 'React Web Admin now also edits product drafts' <<<"$admin_text"
grep -q 'US-047' <<<"$platform_text"
grep -q 'US-047 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-047.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-047.sh' <<<"$app_readme_text"

if grep -R -E -i 'PostgreSQL|MinIO|NATS|Meilisearch|checkout|payment|auth|source GLB upload|delete product' \
  "$app_dir/src"; then
  echo "US-047 must not add direct platform access, checkout, payment, auth, source upload, or delete UI" >&2
  exit 1
fi

pnpm --dir "$app_dir" test
pnpm --dir "$app_dir" build

bazelisk test //apps/web-admin:web-admin-test
bazelisk build //apps/web-admin:web-admin

echo "US-047 verification passed"
