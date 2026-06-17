#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk grep pnpm; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-045" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-045.sh

app_dir="apps/web-admin"
story_file="docs/stories/epics/E04-admin-api/US-045-web-admin-product-list-api-integration.md"

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
  'export type ProductRecord' \
  'export function adminProductsUrl' \
  '/admin/products' \
  'fetchAdminProducts' \
  'ProductListPage' \
  'status: "loading"' \
  'status: "error"' \
  'status: "ready"' \
  'formatPrice' \
  'formatDateTime'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  'product-table' \
  'skeleton-list' \
  'state-message' \
  'error-state' \
  'status-completed' \
  'font-variant-numeric: tabular-nums' \
  '@media (max-width: 760px)'; do
  grep -q "$required" <<<"$style_text"
done

for required in \
  'builds the admin product route' \
  'same-origin API routing' \
  'formats integer-cent display pricing' \
  'renders the loading state' \
  'renders an empty state' \
  'renders an error state' \
  'renders product rows from v1 product records'; do
  grep -q "$required" <<<"$test_text"
done

for required in \
  'US-045 Web Admin Product List API Integration' \
  'GET /admin/products' \
  'loading, empty, failure/retry, and ready states' \
  'This story does not add create, edit, delete, source GLB upload, auth' \
  'Web Admin clients stay behind the Go API gateway'; do
  grep -q "$required" <<<"$story_text"
done

grep -q 'US-045 Web Admin Product List API Integration' <<<"$roadmap_text"
grep -q 'React Web Admin now consumes the product list route' <<<"$admin_text"
grep -q 'US-045' <<<"$platform_text"
grep -q 'US-045 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-045.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-045.sh' <<<"$app_readme_text"

if grep -R -E -i 'PostgreSQL|MinIO|NATS|Meilisearch|checkout|payment|auth|source GLB upload|delete product' \
  "$app_dir/src"; then
  echo "US-045 must not add direct platform access, checkout, payment, auth, source upload, or delete UI" >&2
  exit 1
fi

pnpm --dir "$app_dir" test
pnpm --dir "$app_dir" build

bazelisk test //apps/web-admin:web-admin-test
bazelisk build //apps/web-admin:web-admin

echo "US-045 verification passed"
