#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-021" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-021.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-021-product-search-synchronization.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
readme_text="$(cat services/api-gateway/README.md)"
root_readme_text="$(cat README.md)"
main_text="$(cat services/api-gateway/main.go)"
search_text="$(cat services/api-gateway/internal/search/sync.go)"
search_test_text="$(cat services/api-gateway/internal/search/sync_test.go)"
search_build_text="$(cat services/api-gateway/internal/search/BUILD.bazel)"
product_build_text="$(cat services/api-gateway/internal/product/BUILD.bazel)"
api_build_text="$(cat services/api-gateway/BUILD.bazel)"

grep -q 'US-021 Product Search Synchronization' <<<"$story_text"
grep -q 'product.updated' <<<"$story_text"
grep -q 'Meilisearch `products` index' <<<"$story_text"
grep -q 'This story does not add admin UI behavior' <<<"$story_text"
grep -q 'retry/outbox semantics' <<<"$story_text"

for required in \
  'search-sync consumer for `product.updated`' \
  'reads the authoritative product record' \
  'Meilisearch `products`' \
  'Search sync failures are logged' \
  'customer catalog/search HTTP routes'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'derived Meilisearch `products` index' <<<"$mobile_text"
grep -q 'US-021 Product Search Synchronization' <<<"$roadmap_text"
grep -q 'US-021' <<<"$platform_text"
grep -q 'bash scripts/verify-us-021.sh' <<<"$readme_text"
grep -q 'bash scripts/verify-us-021.sh' <<<"$root_readme_text"

for required in \
  'search.NewSyncer' \
  'search.NewMeilisearchIndexer' \
  'search.NewNATSSubscriber' \
  'Run(context.Background())'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type Syncer struct' \
  'func (syncer Syncer) HandleProductUpdated' \
  'DisallowUnknownFields' \
  'event.Type != "product.updated"' \
  'syncer.reader.GetProduct' \
  'syncer.indexer.UpsertProduct' \
  'type MeilisearchIndexer struct' \
  'func NewProductDocument' \
  '"/indexes/" + productIndexUID + "/documents"' \
  'query.Set("primaryKey", "id")' \
  'type NATSSubscriber struct' \
  'product.ProductUpdatedSubject' \
  'SUB %s %s %s'; do
  grep -q "$required" <<<"$search_text"
done

for required in \
  'TestHandleProductUpdatedIndexesFetchedProduct' \
  'TestHandleProductUpdatedRejectsWrongEventType' \
  'TestHandleProductUpdatedPropagatesReaderFailure' \
  'TestMeilisearchIndexerUpsertsProductDocument' \
  '/indexes/products/documents?primaryKey=id' \
  'Bearer search-key'; do
  grep -q "$required" <<<"$search_test_text"
done

grep -q 'name = "search"' <<<"$search_build_text"
grep -q '//services/api-gateway/internal/search:__pkg__' <<<"$product_build_text"
grep -q '//services/api-gateway/internal/search' <<<"$api_build_text"

if grep -Eqi 'PutObject|meshoptimizer|VisibilityDetector|flutter|BLoC|payment|checkout|event_outbox|CREATE TABLE.*outbox|GET /search|GET /catalog' \
  services/api-gateway/main.go services/api-gateway/internal/search/*.go services/api-gateway/internal/product/*.go services/api-gateway/migrations/*.sql; then
  echo "US-021 must not add uploads, worker processing, UI, checkout, outbox, or customer search routes" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test //services/api-gateway/internal/search:search_test
bazelisk build //services/api-gateway:api-gateway

echo "US-021 verification passed"
