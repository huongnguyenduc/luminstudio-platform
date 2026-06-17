#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-032" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-032.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/lib/features/catalog/domain/catalog_product.dart" \
  "$app_dir/lib/features/catalog/domain/catalog_repository.dart" \
  "$app_dir/lib/features/catalog/domain/load_catalog_products.dart" \
  "$app_dir/lib/features/catalog/domain/search_catalog_products.dart" \
  "$app_dir/lib/features/catalog/data/catalog_api_client.dart" \
  "$app_dir/lib/features/catalog/data/http_catalog_repository.dart" \
  "$app_dir/lib/features/catalog/presentation/cubit/catalog_cubit.dart" \
  "$app_dir/lib/features/catalog/presentation/catalog_products_view.dart" \
  "$app_dir/test/catalog_api_client_test.dart" \
  "$app_dir/test/widget_test.dart"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E09-catalog-search/US-032-flutter-catalog-search-ui-integration.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
api_route_text="$(cat services/api-gateway/main.go services/api-gateway/internal/search/catalog.go)"
app_text="$(cat "$app_dir/lib/app/app.dart")"
catalog_text="$(cat "$app_dir"/lib/features/catalog/domain/*.dart "$app_dir"/lib/features/catalog/data/*.dart "$app_dir"/lib/features/catalog/presentation/*.dart "$app_dir"/lib/features/catalog/presentation/cubit/*.dart)"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-032 Flutter Catalog Search UI Integration' \
  'GET /catalog/search?q=...' \
  'failure/retry' \
  'This story does not add category taxonomy' \
  'Widget tests cover search submit'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-032 Flutter Catalog Search UI Integration' \
  'GET /catalog/search?q=...' \
  'without adding category'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-032' \
  'Home tab catalog search' \
  'repository/use-case boundary' \
  'without connecting directly to Meilisearch'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-032' <<<"$platform_text"
grep -q 'US-032 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-032.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-032.sh' <<<"$app_readme_text"
grep -q 'GET /catalog/search' <<<"$api_route_text"

for required in \
  'SearchCatalogProducts' \
  'searchProducts' \
  '/catalog/search' \
  'SearchBar' \
  'Clear search' \
  'No matching products' \
  'Search is unavailable' \
  'LUMIN_API_BASE_URL'; do
  grep -q "$required" <<<"$catalog_text"$'\n'"$app_text"
done

for required in \
  'CatalogProductsDto accepts catalog search response query metadata' \
  'home tab searches catalog products through the API repository' \
  'home tab renders empty search results' \
  'home tab retries failed catalog searches'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'VisibilityDetector|device_info_plus|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|signed.?url|optimized GLB|Navigator.*product|cart persistence|PostgreSQL|MinIO|NATS' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-032 must not add 360 activation, device-tier behavior, product detail, cart persistence, or direct backend service access" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-032 verification passed"
