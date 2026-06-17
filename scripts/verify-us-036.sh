#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-036" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-036.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const contract = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "product.schema.json"), "utf8"));
const defs = contract.$defs || {};
const detail = defs.ProductDetailResponse;
if (!detail) {
  throw new Error("ProductDetailResponse is missing from product.schema.json");
}
for (const name of ["modelTier", "modelAsset", "modelUrl", "spriteUrl", "meshColorConfig", "informationSections"]) {
  if (!detail.properties?.[name]) {
    throw new Error(`ProductDetailResponse.${name} is missing`);
  }
}
NODE

story_text="$(cat docs/stories/epics/E11-3d-detail/US-036-customer-product-detail-and-tiered-model-access-api.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
mobile_readme_text="$(cat apps/mobile-flutter/README.md)"
contract_text="$(cat packages/shared-types/contracts/v1/product.schema.json packages/shared-types/contracts/v1/README.md)"
main_text="$(cat services/api-gateway/main.go)"
catalog_text="$(cat services/api-gateway/internal/search/catalog.go)"
model_store_text="$(cat services/api-gateway/internal/search/model_assets.go)"
catalog_test_text="$(cat services/api-gateway/internal/search/catalog_test.go)"
main_test_text="$(cat services/api-gateway/main_test.go)"
search_build_text="$(cat services/api-gateway/internal/search/BUILD.bazel)"
api_build_text="$(cat services/api-gateway/BUILD.bazel)"

grep -q 'US-036 Customer Product Detail And Tiered Model Access API' <<<"$story_text"
grep -q 'GET /catalog/products/{id}?tier=low|high' <<<"$story_text"
grep -q 'GET /catalog/products/{id}/model?tier=low|high' <<<"$story_text"
grep -q 'This story does not add Flutter device-tier detection' <<<"$story_text"
grep -q 'signed object URLs' <<<"$story_text"

for required in \
  'US-036 Customer Product Detail And Tiered Model Access API' \
  'GET /catalog/products/{id}?tier=low|high' \
  'GET /catalog/products/{id}/model?tier=low|high' \
  'does not add Flutter device-tier'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'GET /catalog/products/{id}?tier=low|high' \
  'GET /catalog/products/{id}/model?tier=low|high' \
  'authoritative product row' \
  'direct service access remain deferred'; do
  grep -q "$required" <<<"$mobile_text"
done

for required in \
  'customer product detail' \
  'authoritative product row first' \
  'direct MinIO URLs' \
  'Flutter 3D viewer behavior'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-036' <<<"$platform_text"
grep -q 'US-036 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-036.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-036.sh' <<<"$api_readme_text"
grep -q 'GET /catalog/products/{id}/model?tier=low|high' <<<"$mobile_readme_text"

for required in \
  'ProductDetailResponse' \
  'modelTier' \
  'modelUrl' \
  'spriteUrl' \
  'GET /catalog/products/{id}/model?tier=low|high' \
  'not direct MinIO'; do
  grep -q "$required" <<<"$contract_text"
done

for required in \
  'WithModelAssetStore(search.NewMinIOModelAssetStore' \
  'GET /catalog/products/{id}' \
  'GET /catalog/products/{id}/model'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type ModelAssetStore interface' \
  'type ProductDetailResponse struct' \
  'func (handler Handler) GetCatalogProductDetail' \
  'func (handler Handler) GetCatalogProductModel' \
  'modelTierFromRequest' \
  'modelAssetForTier' \
  'lumin-optimized-glb' \
  'lumin-source-glb' \
  'model/gltf-binary' \
  'Cache-Control'; do
  grep -q "$required" <<<"$catalog_text"
done

for required in \
  'type MinIOModelAssetStore struct' \
  'func NewMinIOModelAssetStore' \
  'GetModelAsset' \
  'lumin-source-glb' \
  'lumin-optimized-glb' \
  'GetObject'; do
  grep -q "$required" <<<"$model_store_text"
done

for required in \
  'TestGetCatalogProductDetailReturnsTieredModelAccess' \
  'TestGetCatalogProductDetailRejectsInvalidTier' \
  'TestGetCatalogProductDetailRequiresCompletedModelAsset' \
  'TestGetCatalogProductModelStreamsLowTierModel' \
  'TestGetCatalogProductModelStreamsHighTierSourceModel' \
  'TestGetCatalogProductModelReportsStorageFailure'; do
  grep -q "$required" <<<"$catalog_test_text"
done

grep -q 'TestRoutesExposeCatalogProductDetail' <<<"$main_test_text"
grep -q 'TestRoutesExposeCatalogProductModel' <<<"$main_test_text"
grep -q 'model_assets.go' <<<"$search_build_text"
grep -q '@com_github_minio_minio_go_v7//:minio-go' <<<"$search_build_text"
grep -q '//services/api-gateway/internal/search' <<<"$api_build_text"

if grep -Eqi 'device_info_plus|VisibilityDetector|flutter_bloc|signed.?url|checkout|payment|event_outbox|dead.?letter|POST /catalog|PUT /catalog|DELETE /catalog' \
  services/api-gateway/main.go services/api-gateway/internal/search/*.go services/api-gateway/internal/product/*.go services/api-gateway/migrations/*.sql; then
  echo "US-036 must not add Flutter device-tier/viewer code, signed URLs, checkout, outbox/dead-letter, or catalog mutations" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/search:search_test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway:api-gateway //packages/shared-types:contracts_v1

echo "US-036 verification passed"
