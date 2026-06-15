#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-029" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-029.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const contract = JSON.parse(fs.readFileSync(path.join("packages", "shared-types", "contracts", "v1", "product.schema.json"), "utf8"));
const defs = contract.$defs || {};
for (const name of ["CatalogItem", "CatalogSearchResponse"]) {
  if (!defs[name]) {
    throw new Error(`${name} is missing from product.schema.json`);
  }
}
NODE

story_text="$(cat docs/stories/epics/E09-catalog-search/US-029-customer-catalog-search-http-api.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
contract_text="$(cat packages/shared-types/contracts/v1/product.schema.json packages/shared-types/contracts/v1/README.md)"
main_text="$(cat services/api-gateway/main.go)"
catalog_text="$(cat services/api-gateway/internal/search/catalog.go)"
sync_text="$(cat services/api-gateway/internal/search/sync.go)"
catalog_test_text="$(cat services/api-gateway/internal/search/catalog_test.go)"
main_test_text="$(cat services/api-gateway/main_test.go)"
search_build_text="$(cat services/api-gateway/internal/search/BUILD.bazel)"
api_build_text="$(cat services/api-gateway/BUILD.bazel)"

grep -q 'US-029 Customer Catalog Search HTTP API' <<<"$story_text"
grep -q 'GET /catalog/products' <<<"$story_text"
grep -q 'GET /catalog/search?q=' <<<"$story_text"
grep -q 'This story does not add Flutter UI' <<<"$story_text"
grep -q 'retry/outbox semantics' <<<"$story_text"

for required in \
  'US-029 Customer Catalog Search HTTP API' \
  'GET /catalog/products' \
  'GET /catalog/search?q=' \
  'without adding Flutter UI'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'GET /catalog/products' \
  'GET /catalog/search?q=' \
  'API boundary' \
  '360-degree sprite asset'; do
  grep -q "$required" <<<"$mobile_text"
done

for required in \
  'first customer-facing catalog/search boundary' \
  'Meilisearch `products` index' \
  'Clients remain behind' \
  'category taxonomy'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-029' <<<"$platform_text"
grep -q 'US-029 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-029.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-029.sh' <<<"$api_readme_text"

for required in \
  'CatalogItem' \
  'CatalogSearchResponse' \
  'spriteAsset' \
  'customer catalog item'; do
  grep -q "$required" <<<"$contract_text"
done

for required in \
  'search.NewHandler(search.NewMeilisearchSearcher' \
  'GET /catalog/products' \
  'GET /catalog/search'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type ProductSearcher interface' \
  'type CatalogSearchResponse struct' \
  'func (handler Handler) ListCatalogProducts' \
  'func (handler Handler) SearchCatalogProducts' \
  'q query parameter is required' \
  'maxCatalogLimit' \
  'type MeilisearchSearcher struct' \
  '"/indexes/" + productIndexUID + "/search"' \
  '"q":      query.Query' \
  'Authorization"'; do
  grep -q "$required" <<<"$catalog_text"
done

grep -q 'SpriteAsset' <<<"$sync_text"

for required in \
  'TestListCatalogProductsReturnsCustomerSafeItems' \
  'TestSearchCatalogProductsRequiresQuery' \
  'TestSearchCatalogProductsValidatesLimit' \
  'TestSearchCatalogProductsReportsBackendFailure' \
  'TestMeilisearchSearcherSearchesProducts' \
  '/indexes/products/search' \
  'informationText'; do
  grep -q "$required" <<<"$catalog_test_text"
done

grep -q 'TestRoutesExposeCatalogProducts' <<<"$main_test_text"
grep -q 'TestRoutesExposeCatalogSearch' <<<"$main_test_text"
grep -q 'catalog.go' <<<"$search_build_text"
grep -q 'catalog_test.go' <<<"$search_build_text"
grep -q '//services/api-gateway/internal/search' <<<"$api_build_text"

if grep -Eqi 'VisibilityDetector|Bloc|flutter|device_info_plus|signed.?url|checkout|payment|event_outbox|dead.?letter|CREATE TABLE.*outbox|PUT /catalog|POST /catalog|DELETE /catalog' \
  services/api-gateway/main.go services/api-gateway/internal/search/*.go services/api-gateway/internal/product/*.go services/api-gateway/migrations/*.sql; then
  echo "US-029 must not add Flutter UI, signed URLs, checkout, outbox/dead-letter, catalog mutations, or new SQL behavior" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/search:search_test
bazelisk build //services/api-gateway:api-gateway //packages/shared-types:contracts_v1

echo "US-029 verification passed"
