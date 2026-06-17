#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-043" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-043.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/lib/features/catalog/domain/catalog_product.dart" \
  "$app_dir/lib/features/catalog/domain/catalog_repository.dart" \
  "$app_dir/lib/features/catalog/domain/load_catalog_categories.dart" \
  "$app_dir/lib/features/catalog/domain/load_category_products.dart" \
  "$app_dir/lib/features/catalog/data/catalog_api_client.dart" \
  "$app_dir/lib/features/catalog/data/http_catalog_repository.dart" \
  "$app_dir/lib/features/catalog/presentation/cubit/category_cubit.dart" \
  "$app_dir/lib/features/catalog/presentation/category_products_view.dart" \
  "$app_dir/lib/features/shell/presentation/shell_page.dart" \
  "$app_dir/test/catalog_api_client_test.dart" \
  "$app_dir/test/widget_test.dart"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E09-catalog-search/US-043-flutter-category-tab-api-integration.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
catalog_domain_text="$(cat "$app_dir"/lib/features/catalog/domain/*.dart)"
catalog_data_text="$(cat "$app_dir"/lib/features/catalog/data/*.dart)"
category_presentation_text="$(cat "$app_dir"/lib/features/catalog/presentation/category_products_view.dart "$app_dir"/lib/features/catalog/presentation/cubit/category_cubit.dart)"
shell_text="$(cat "$app_dir"/lib/features/shell/presentation/shell_page.dart)"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-043 Flutter Category Tab API Integration' \
  'GET /catalog/categories' \
  'GET /catalog/categories/{slug}/products?sort=...&limit=...&offset=...' \
  'This story does not add checkout, payments, authentication, authorization' \
  'Widget tests cover category loading, sort changes, pagination, and retry'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-043 Flutter Category Tab API Integration' \
  'without adding checkout' \
  'scroll-to-top'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-043' \
  'connects the Flutter Category tab' \
  'supports the v1 sort values' \
  'direct service access remain deferred'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-043' <<<"$platform_text"
grep -q 'Flutter Category tab' <<<"$admin_text"
grep -q 'US-043 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-043.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-043.sh' <<<"$app_readme_text"

for required in \
  'class CatalogCategory' \
  'enum CategoryProductSort' \
  'listCategories' \
  'listCategoryProducts' \
  'LoadCatalogCategories' \
  'LoadCategoryProducts'; do
  grep -q "$required" <<<"$catalog_domain_text"
done

for required in \
  '/catalog/categories' \
  '/catalog/categories/${Uri.encodeComponent(categorySlug)}/products' \
  'CategoryListDto' \
  'CatalogCategoryDto' \
  'categorySlug' \
  'CategoryProductSort.parse'; do
  grep -q "$required" <<<"$catalog_data_text"
done

for required in \
  'class CategoryCubit' \
  'loadCategories' \
  'changeSort' \
  'loadMoreProducts' \
  'More category products are unavailable' \
  'All category products loaded' \
  'Scroll categories to top' \
  'CategoryProductSort.values'; do
  grep -q "$required" <<<"$category_presentation_text"
done

grep -q 'CategoryProductsView' <<<"$shell_text"

for required in \
  'CategoryListDto parses the v1 category list response shape' \
  'CatalogProductsDto accepts category product metadata' \
  'category tab loads categories and first category products' \
  'category tab changes product sort through the API repository' \
  'category tab paginates products and retries inline failures'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'checkout|payment|auth|inventory|signed.?url|PostgreSQL|MinIO|NATS|Meilisearch' \
  "$app_dir/lib" "$app_dir/test"; then
  echo "US-043 must not add checkout, payment, auth, inventory, signed URLs, or direct backend service access" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-043 verification passed"
