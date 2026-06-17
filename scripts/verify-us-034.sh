#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk file go grep node shasum; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-034" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-034.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const contract = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "product.schema.json"), "utf8"));
const defs = contract.$defs || {};
if (!defs.CatalogItem?.properties?.spriteAsset) {
  throw new Error("CatalogItem.spriteAsset is missing from product.schema.json");
}
NODE

expected_sprite_sha="23eae501e2de09d32c62a144b95e4d1a399dee3611b57b0d96c7944ecb649866"
actual_sprite_sha="$(shasum -a 256 resources/pet_tag_360_sprite.jpg | awk '{print $1}')"
if [[ "$actual_sprite_sha" != "$expected_sprite_sha" ]]; then
  echo "resources/pet_tag_360_sprite.jpg sha mismatch: $actual_sprite_sha" >&2
  exit 1
fi
file resources/pet_tag_360_sprite.jpg | grep -q '960x640'

story_text="$(cat docs/stories/epics/E09-catalog-search/US-034-customer-sprite-preview-asset-access-api.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
mobile_readme_text="$(cat apps/mobile-flutter/README.md)"
contract_readme_text="$(cat packages/shared-types/contracts/v1/README.md)"
resource_build_text="$(cat resources/BUILD.bazel)"
main_text="$(cat services/api-gateway/main.go)"
catalog_text="$(cat services/api-gateway/internal/search/catalog.go)"
sprite_store_text="$(cat services/api-gateway/internal/search/sprite_assets.go)"
catalog_test_text="$(cat services/api-gateway/internal/search/catalog_test.go)"
main_test_text="$(cat services/api-gateway/main_test.go)"
search_build_text="$(cat services/api-gateway/internal/search/BUILD.bazel)"
api_build_text="$(cat services/api-gateway/BUILD.bazel)"

grep -q 'US-034 Customer Sprite Preview Asset Access API' <<<"$story_text"
grep -q 'GET /catalog/products/{id}/sprite' <<<"$story_text"
grep -q 'resources/pet_tag_360_sprite.jpg' <<<"$story_text"
grep -q "$expected_sprite_sha" <<<"$story_text"
grep -q 'does not add Flutter preview activation' <<<"$story_text"

for required in \
  'US-034 Customer Sprite Preview Asset Access API' \
  'GET /catalog/products/{id}/sprite' \
  'without adding Flutter preview activation'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'GET /catalog/products/{id}/sprite' \
  'do not access MinIO' \
  'Flutter preview activation'; do
  grep -q "$required" <<<"$mobile_text"
done

for required in \
  'GET /catalog/products/{id}/sprite' \
  'authoritative product row' \
  'Flutter preview activation'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-034' <<<"$platform_text"
grep -q 'US-034 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-034.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-034.sh' <<<"$api_readme_text"
grep -q 'GET /catalog/products/{id}/sprite' <<<"$mobile_readme_text"
grep -q 'Binary Asset Routes' <<<"$contract_readme_text"
grep -q 'GET /catalog/products/{id}/sprite' <<<"$contract_readme_text"
grep -q 'pet_tag_360_sprite' <<<"$resource_build_text"

for required in \
  'WithCatalogProductReader(productStore)' \
  'WithSpriteAssetStore(search.NewMinIOSpriteAssetStore' \
  'GET /catalog/products/{id}/sprite'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type CatalogProductReader interface' \
  'type SpriteAssetStore interface' \
  'func (handler Handler) GetCatalogProductSprite' \
  'product.ValidProductID' \
  'ProcessingCompleted' \
  'Content-Type' \
  'image/jpeg' \
  'Cache-Control'; do
  grep -q "$required" <<<"$catalog_text"
done

for required in \
  'type MinIOSpriteAssetStore struct' \
  'func NewMinIOSpriteAssetStore' \
  'GetSpriteAsset' \
  'lumin-360-sprites' \
  'GetObject'; do
  grep -q "$required" <<<"$sprite_store_text"
done

for required in \
  'TestGetCatalogProductSpriteStreamsCompletedSprite' \
  'TestGetCatalogProductSpriteRejectsInvalidID' \
  'TestGetCatalogProductSpriteRequiresCompletedSprite' \
  'TestGetCatalogProductSpriteReportsStorageFailure'; do
  grep -q "$required" <<<"$catalog_test_text"
done

grep -q 'TestRoutesExposeCatalogProductSprite' <<<"$main_test_text"
grep -q 'sprite_assets.go' <<<"$search_build_text"
grep -q '@com_github_minio_minio_go_v7//:minio-go' <<<"$search_build_text"
grep -q '//services/api-gateway/internal/search' <<<"$api_build_text"

if grep -Eqi 'VisibilityDetector|device_info_plus|flutter_bloc|signed.?url|checkout|payment|event_outbox|dead.?letter|POST /catalog|PUT /catalog|DELETE /catalog' \
  services/api-gateway/main.go services/api-gateway/internal/search/*.go services/api-gateway/internal/product/*.go services/api-gateway/migrations/*.sql; then
  echo "US-034 must not add Flutter preview activation, signed URLs, checkout, outbox/dead-letter, or catalog mutations" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/search:search_test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway:api-gateway //packages/shared-types:contracts_v1 //resources:pet_tag_360_sprite

echo "US-034 verification passed"
