#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-051" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-051.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const common = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "common.schema.json"), "utf8"));
const product = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "product.schema.json"), "utf8"));
if (!common.$defs?.CartId) {
  throw new Error("CartId is missing from common.schema.json");
}
const defs = product.$defs || {};
for (const defName of ["CartItemInput", "CartUpsertRequest", "CartItemSnapshot", "CartTotals", "CartRecord"]) {
  if (!defs[defName]) {
    throw new Error(`${defName} is missing from product.schema.json`);
  }
}
for (const name of ["items", "totals", "createdAt", "updatedAt"]) {
  if (!defs.CartRecord.properties?.[name]) {
    throw new Error(`CartRecord.${name} is missing`);
  }
}
NODE

story_text="$(cat docs/stories/epics/E14-backend-cart/US-051-customer-backend-cart-api-contract-and-persistence-foundation.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
overview_text="$(cat docs/product/overview.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
contract_readme_text="$(cat packages/shared-types/contracts/v1/README.md)"
common_schema_text="$(cat packages/shared-types/contracts/v1/common.schema.json)"
schema_text="$(cat packages/shared-types/contracts/v1/product.schema.json)"
migration_text="$(cat services/api-gateway/migrations/004_create_carts.sql)"
migration_build_text="$(cat services/api-gateway/migrations/BUILD.bazel)"
cart_model_text="$(cat services/api-gateway/internal/cart/model.go)"
cart_store_text="$(cat services/api-gateway/internal/cart/store.go)"
cart_handler_text="$(cat services/api-gateway/internal/cart/handler.go)"
cart_tests_text="$(cat services/api-gateway/internal/cart/model_test.go services/api-gateway/internal/cart/store_test.go services/api-gateway/internal/cart/handler_test.go services/api-gateway/main_test.go)"
main_text="$(cat services/api-gateway/main.go)"
api_build_text="$(cat services/api-gateway/BUILD.bazel)"
cart_build_text="$(cat services/api-gateway/internal/cart/BUILD.bazel)"

for required in \
  'US-051 Customer Backend Cart API Contract And Persistence Foundation' \
  'POST /cart' \
  'GET /cart/{id}' \
  'PUT /cart/{id}' \
  'does not add checkout, payments'; do
  grep -Fq "$required" <<<"$story_text"
done

for source in "$roadmap_text" "$mobile_text" "$admin_text" "$platform_text" "$root_readme_text" "$api_readme_text"; do
  grep -Fq 'US-051' <<<"$source"
  grep -Fq 'POST /cart' <<<"$source"
done

grep -Fq 'US-051 implemented' <<<"$backlog_text"
grep -Fq 'backend cart snapshot API' <<<"$overview_text"
grep -Fq 'backend cart snapshots' <<<"$contract_readme_text"

for required in \
  'CartId' \
  'cart_'; do
  grep -Fq "$required" <<<"$common_schema_text"
done

for required in \
  'CartUpsertRequest' \
  'CartItemSnapshot' \
  'CartTotals' \
  'CartRecord'; do
  grep -Fq "$required" <<<"$schema_text"
done

for required in \
  'CREATE TABLE carts' \
  'jsonb_array_length(items) <= 100' \
  'carts_updated_at_idx'; do
  grep -Fq "$required" <<<"$migration_text"
done
grep -Fq '004_create_carts.sql' <<<"$migration_build_text"

for required in \
  'type UpsertRequest struct' \
  'func BuildSnapshots' \
  'func CalculateTotals' \
  'func validateSelectedColors' \
  'MixedCurrency'; do
  grep -Fq "$required" <<<"$cart_model_text"
done

for required in \
  'INSERT INTO carts' \
  'UPDATE carts' \
  'SELECT id, items, totals' \
  'encode cart items' \
  'decode cart totals'; do
  grep -Fq "$required" <<<"$cart_store_text"
done

for required in \
  'CreateCart' \
  'GetCart' \
  'UpdateCart' \
  'cart item product not found'; do
  grep -Fq "$required" <<<"$cart_handler_text"
done

for required in \
  'POST /cart' \
  'GET /cart/{id}' \
  'PUT /cart/{id}'; do
  grep -Fq "$required" <<<"$main_text"
done

for required in \
  '//services/api-gateway/internal/cart'; do
  grep -Fq "$required" <<<"$api_build_text"
done
for required in \
  'cart_test' \
  'internal/cart'; do
  grep -Fq "$required" <<<"$cart_build_text"
done

for required in \
  'TestBuildSnapshotsUsesAuthoritativeProductData' \
  'TestCreateCartSnapshotsProductAndReturnsCreated' \
  'TestRoutesExposeCartCreate'; do
  grep -Fq "$required" <<<"$cart_tests_text"
done

for forbidden in '/checkout' '/payment' '/orders' '/login' '/auth' '/inventory'; do
  if grep -Fq "$forbidden" <<<"$main_text"; then
    echo "US-051 must not add ${forbidden} routes" >&2
    exit 1
  fi
done

(cd services/api-gateway && go test ./...)
bazelisk build //packages/shared-types:contracts_v1 //services/api-gateway:api-gateway //services/api-gateway/migrations:migrations
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/cart:cart_test

echo "US-051 verification passed"
