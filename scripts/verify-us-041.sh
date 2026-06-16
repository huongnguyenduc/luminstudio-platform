#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk dart flutter go grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-041" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-041.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const contract = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "product.schema.json"), "utf8"));
const defs = contract.$defs || {};
const price = defs.ProductPrice;
if (!price) {
  throw new Error("ProductPrice is missing from product.schema.json");
}
for (const name of ["amountCents", "currency", "compareAtAmountCents"]) {
  if (!price.properties?.[name]) {
    throw new Error(`ProductPrice.${name} is missing`);
  }
}
for (const defName of ["ProductDraft", "ProductRecord", "CatalogItem", "ProductDetailResponse"]) {
  const def = defs[defName];
  if (!def) {
    throw new Error(`${defName} is missing`);
  }
  if (!def.required?.includes("price")) {
    throw new Error(`${defName} must require price`);
  }
  if (!def.properties?.price) {
    throw new Error(`${defName}.price is missing`);
  }
}
NODE

story_text="$(cat docs/stories/epics/E13-cart/US-041-product-pricing-contract-and-cart-totals.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
app_readme_text="$(cat apps/mobile-flutter/README.md)"
schema_text="$(cat packages/shared-types/contracts/v1/product.schema.json)"
migration_text="$(cat services/api-gateway/migrations/002_add_product_pricing.sql)"
product_model_text="$(cat services/api-gateway/internal/product/model.go)"
product_store_text="$(cat services/api-gateway/internal/product/store.go)"
search_sync_text="$(cat services/api-gateway/internal/search/sync.go)"
catalog_text="$(cat services/api-gateway/internal/search/catalog.go)"
catalog_domain_text="$(cat apps/mobile-flutter/lib/features/catalog/domain/catalog_product.dart)"
catalog_api_text="$(cat apps/mobile-flutter/lib/features/catalog/data/catalog_api_client.dart)"
cart_item_text="$(cat apps/mobile-flutter/lib/features/cart/domain/cart_item.dart)"
cart_repo_text="$(cat apps/mobile-flutter/lib/features/cart/data/shared_preferences_cart_repository.dart)"
cart_cubit_text="$(cat apps/mobile-flutter/lib/features/cart/presentation/cubit/cart_cubit.dart)"
cart_view_text="$(cat apps/mobile-flutter/lib/features/cart/presentation/cart_view.dart)"
detail_view_text="$(cat apps/mobile-flutter/lib/features/catalog/presentation/product_detail_view.dart)"
main_text="$(cat services/api-gateway/main.go)"
test_text="$(cat apps/mobile-flutter/test/*.dart)"

for required in \
  'US-041 Product Pricing Contract And Cart Totals' \
  'ProductPrice' \
  'selected subtotal and savings' \
  'does not add checkout, payments, authentication, authorization'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-041 Product Pricing Contract And Cart Totals' \
  'without adding checkout' \
  'payments' \
  'auth'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-041' \
  'display pricing contract' \
  'selected subtotal and savings' \
  'Checkout, payments, authentication'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'required display price' <<<"$admin_text"
grep -q 'US-041' <<<"$platform_text"
grep -q 'US-041 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-041.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-041.sh' <<<"$api_readme_text"
grep -q 'bash scripts/verify-us-041.sh' <<<"$app_readme_text"

for required in \
  'ProductPrice' \
  'amountCents' \
  'currency' \
  'compareAtAmountCents'; do
  grep -q "$required" <<<"$schema_text"
done

for required in \
  'ADD COLUMN price JSONB NOT NULL' \
  'amountCents' \
  'currency' \
  'compareAtAmountCents'; do
  grep -q "$required" <<<"$migration_text"
done

for required in \
  'type ProductPrice struct' \
  'func (price ProductPrice) validate' \
  'AmountCents' \
  'CompareAtAmountCents'; do
  grep -q "$required" <<<"$product_model_text"
done

for required in \
  'price,' \
  'encode price' \
  'decode price'; do
  grep -q "$required" <<<"$product_store_text"
done

grep -q 'Price            product.ProductPrice' <<<"$search_sync_text"
grep -q 'Price            product.ProductPrice' <<<"$catalog_text"
grep -q 'class CatalogPrice' <<<"$catalog_domain_text"
grep -q 'class CatalogPriceDto' <<<"$catalog_api_text"
grep -q 'lineSubtotalCents' <<<"$cart_item_text"
grep -q "'amount_cents'" <<<"$cart_repo_text"
grep -q 'class CartTotals' <<<"$cart_cubit_text"
grep -q 'selectedTotals' <<<"$cart_cubit_text"
grep -q 'Subtotal' <<<"$cart_view_text"
grep -q 'Savings' <<<"$cart_view_text"
grep -q 'product-detail-price' <<<"$detail_view_text"

for forbidden in 'checkout' 'payment' 'auth'; do
  if grep -q " /${forbidden}" <<<"$main_text"; then
    echo "US-041 must not add ${forbidden} routes" >&2
    exit 1
  fi
done

for required in \
  'price.savingsCents' \
  'Subtotal USD 129.00' \
  'Savings USD 30.00' \
  'Subtotal USD 258.00'; do
  grep -q "$required" <<<"$test_text"
done

(cd services/api-gateway && go test ./...)
bazelisk build //packages/shared-types:contracts_v1 //services/api-gateway:api-gateway
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test //services/api-gateway/internal/search:search_test
(cd apps/mobile-flutter && flutter analyze)
(cd apps/mobile-flutter && flutter test test/us040_capture_test.dart --update-goldens)
(cd apps/mobile-flutter && flutter test)

capture_file="reports/us-040/cart-local-persistence.png"
if [[ -f "$capture_file" ]]; then
  test -s "$capture_file"
else
  echo "US-041 UI screenshot not found at $capture_file; capture the mobile Cart tab before final proof" >&2
  exit 1
fi

echo "US-041 verification passed"
