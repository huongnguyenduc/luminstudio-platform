#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk grep pnpm; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-046" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-046.sh

app_dir="apps/web-admin"
story_file="docs/stories/epics/E04-admin-api/US-046-web-admin-product-create-api-integration.md"

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
  'export type ProductDraft' \
  'export type ProductFormValues' \
  'export type ProductCreateState' \
  'export async function createAdminProduct' \
  'export function buildProductDraft' \
  'ProductCreatePanel' \
  'POST' \
  'Content-Type": "application/json"' \
  'amountCents' \
  'compareAtAmountCents' \
  'categoriesJson' \
  'informationSectionsJson' \
  'meshColorConfigJson' \
  'Slug must use lowercase letters' \
  'Currency must be a three-letter uppercase code' \
  'Compare-at price must be greater than the display price' \
  'await reloadProducts()'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  'create-panel' \
  'product-form' \
  'form-grid' \
  'form-message-error' \
  'form-message-success' \
  'primary-button' \
  'font-variant-numeric: tabular-nums' \
  '@media (max-width: 760px)'; do
  grep -q "$required" <<<"$style_text"
done

for required in \
  'builds the v1 product draft body from form values' \
  'rejects invalid slug and malformed JSON before submit' \
  'posts the product draft to the admin create route' \
  'renders the create form' \
  'renders submitting and success states' \
  'renders create failure inline' \
  'renders product rows from v1 product records'; do
  grep -q "$required" <<<"$test_text"
done

for required in \
  'US-046 Web Admin Product Create API Integration' \
  'POST /admin/products' \
  'success, and failure states' \
  'This story does not add product edit, delete, source GLB upload' \
  'Web Admin clients stay behind the Go API gateway'; do
  grep -q "$required" <<<"$story_text"
done

grep -q 'US-046 Web Admin Product Create API Integration' <<<"$roadmap_text"
grep -q 'React Web Admin now also creates product drafts' <<<"$admin_text"
grep -q 'US-046' <<<"$platform_text"
grep -q 'US-046 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-046.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-046.sh' <<<"$app_readme_text"

if grep -R -E -i 'PostgreSQL|MinIO|NATS|Meilisearch|checkout|payment|auth|source GLB upload|delete product|edit product' \
  "$app_dir/src"; then
  echo "US-046 must not add direct platform access, checkout, payment, auth, source upload, edit, or delete UI" >&2
  exit 1
fi

pnpm --dir "$app_dir" test
pnpm --dir "$app_dir" build

bazelisk test //apps/web-admin:web-admin-test
bazelisk build //apps/web-admin:web-admin

echo "US-046 verification passed"
