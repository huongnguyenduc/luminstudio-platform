#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-042" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-042.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const contract = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "product.schema.json"), "utf8"));
const defs = contract.$defs || {};
if (!defs.ProductCategory) {
  throw new Error("ProductCategory is missing from product.schema.json");
}
for (const name of ["slug", "name"]) {
  if (!defs.ProductCategory.properties?.[name]) {
    throw new Error(`ProductCategory.${name} is missing`);
  }
}
for (const defName of ["ProductDraft", "ProductRecord", "CatalogItem", "ProductDetailResponse"]) {
  const def = defs[defName];
  if (!def?.properties?.categories) {
    throw new Error(`${defName}.categories is missing`);
  }
}
if (!defs.CategoryListResponse?.properties?.categories) {
  throw new Error("CategoryListResponse.categories is missing");
}
if (!defs.CatalogSearchResponse?.properties?.categorySlug || !defs.CatalogSearchResponse?.properties?.sort) {
  throw new Error("CatalogSearchResponse category metadata is missing");
}
NODE

story_text="$(cat docs/stories/epics/E09-catalog-search/US-042-customer-category-taxonomy-and-sorting-api.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
contract_readme_text="$(cat packages/shared-types/contracts/v1/README.md)"
schema_text="$(cat packages/shared-types/contracts/v1/product.schema.json)"
migration_text="$(cat services/api-gateway/migrations/003_add_product_categories.sql)"
migration_build_text="$(cat services/api-gateway/migrations/BUILD.bazel)"
product_model_text="$(cat services/api-gateway/internal/product/model.go)"
product_store_text="$(cat services/api-gateway/internal/product/store.go)"
search_sync_text="$(cat services/api-gateway/internal/search/sync.go)"
catalog_text="$(cat services/api-gateway/internal/search/catalog.go)"
main_text="$(cat services/api-gateway/main.go)"
test_text="$(cat services/api-gateway/internal/search/catalog_test.go services/api-gateway/internal/search/sync_test.go services/api-gateway/internal/product/model_test.go)"

for required in \
  'US-042 Customer Category Taxonomy And Sorting API' \
  'GET /catalog/categories' \
  'GET /catalog/categories/{slug}/products' \
  'does not add Flutter Category tab UI, checkout, payments'; do
  grep -Fq "$required" <<<"$story_text"
done

for source in "$roadmap_text" "$mobile_text" "$admin_text" "$platform_text" "$root_readme_text" "$api_readme_text"; do
  grep -Fq 'US-042' <<<"$source"
  grep -Fq 'catalog/categories' <<<"$source"
done

grep -Fq 'US-042 implemented' <<<"$backlog_text"
grep -Fq 'product category' <<<"$contract_readme_text"

for required in \
  'ProductCategory' \
  'CategoryListResponse' \
  'categorySlug' \
  'price_asc' \
  'name_asc'; do
  grep -Fq "$required" <<<"$schema_text"
done

for required in \
  'ADD COLUMN categories JSONB NOT NULL' \
  'jsonb_array_length(categories) <= 8' \
  'products_categories_gin_idx'; do
  grep -Fq "$required" <<<"$migration_text"
done
grep -Fq '003_add_product_categories.sql' <<<"$migration_build_text"

for required in \
  'type ProductCategory struct' \
  'func validateCategories' \
  'func ValidSlug' \
  'Categories          []ProductCategory'; do
  grep -Fq "$required" <<<"$product_model_text"
done

for required in \
  'categories,' \
  'encode categories' \
  'decode categories'; do
  grep -Fq "$required" <<<"$product_store_text"
done

for required in \
  'CategorySlugs' \
  'CategoryKeys' \
  'PriceAmountCents' \
  'filterableAttributes' \
  'sortableAttributes'; do
  grep -Fq "$required" <<<"$search_sync_text"
done

for required in \
  'ListCatalogCategories' \
  'ListCategoryProducts' \
  'CategoryListResponse' \
  'facetDistribution' \
  'categorySlugs = ' \
  'priceAmountCents:asc'; do
  grep -Fq "$required" <<<"$catalog_text"
done

for required in \
  'GET /catalog/categories' \
  'GET /catalog/categories/{slug}/products'; do
  grep -Fq "$required" <<<"$main_text"
done

for required in \
  'TestListCatalogCategoriesReturnsTaxonomy' \
  'TestListCategoryProductsFiltersAndSorts' \
  'TestMeilisearchSearcherListsCategories' \
  'duplicate category slug'; do
  grep -Fq "$required" <<<"$test_text"
done

for forbidden in 'checkout' 'payment' 'auth' 'inventory'; do
  if grep -Fq " /${forbidden}" <<<"$main_text"; then
    echo "US-042 must not add ${forbidden} routes" >&2
    exit 1
  fi
done

(cd services/api-gateway && go test ./...)
bazelisk build //packages/shared-types:contracts_v1 //services/api-gateway:api-gateway //services/api-gateway/migrations:migrations
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test //services/api-gateway/internal/search:search_test

echo "US-042 verification passed"
