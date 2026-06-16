#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-031" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-031.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/lib/features/catalog/domain/catalog_product.dart" \
  "$app_dir/lib/features/catalog/domain/catalog_repository.dart" \
  "$app_dir/lib/features/catalog/domain/load_catalog_products.dart" \
  "$app_dir/lib/features/catalog/data/catalog_api_client.dart" \
  "$app_dir/lib/features/catalog/data/http_catalog_repository.dart" \
  "$app_dir/lib/features/catalog/presentation/cubit/catalog_cubit.dart" \
  "$app_dir/lib/features/catalog/presentation/catalog_products_view.dart" \
  "$app_dir/lib/features/shell/presentation/shell_page.dart" \
  "$app_dir/test/catalog_api_client_test.dart" \
  "$app_dir/test/widget_test.dart"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E09-catalog-search/US-031-flutter-catalog-products-api-integration.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
contract_text="$(cat packages/shared-types/contracts/v1/product.schema.json)"
api_route_text="$(cat services/api-gateway/main.go services/api-gateway/internal/search/catalog.go)"
app_text="$(cat "$app_dir/lib/app/app.dart")"
catalog_text="$(cat "$app_dir"/lib/features/catalog/domain/*.dart "$app_dir"/lib/features/catalog/data/*.dart "$app_dir"/lib/features/catalog/presentation/*.dart "$app_dir"/lib/features/catalog/presentation/cubit/*.dart)"
shell_text="$(cat "$app_dir/lib/features/shell/presentation/shell_page.dart")"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-031 Flutter Catalog Products API Integration' \
  'GET /catalog/products' \
  'This story does not add catalog search UI' \
  'LUMIN_API_BASE_URL' \
  'Widget tests cover empty, ready, failure/retry'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-031 Flutter Catalog Products API Integration' \
  'GET /catalog/products' \
  'without adding search UI'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-031' \
  'loads catalog product cards' \
  'API boundary' \
  'not activate'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-031' <<<"$platform_text"
grep -q 'US-031 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-031.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-031.sh' <<<"$app_readme_text"

for required in \
  'CatalogItem' \
  'CatalogSearchResponse' \
  'spriteAsset'; do
  grep -q "$required" <<<"$contract_text"
done

grep -q 'GET /catalog/products' <<<"$api_route_text"

for required in \
  'CatalogApiClient' \
  '/catalog/products' \
  'CatalogRepository' \
  'LoadCatalogProducts' \
  'class CatalogCubit extends Cubit<CatalogState>' \
  'CatalogStatus.loading' \
  'CatalogStatus.empty' \
  'CatalogStatus.failure' \
  'CatalogProductsView' \
  'LUMIN_API_BASE_URL'; do
  grep -q "$required" <<<"$catalog_text"$'\n'"$app_text"
done

for required in \
  'CatalogProductsView' \
  'PageStorageKey<String>('; do
  grep -q "$required" <<<"$shell_text"
done

for required in \
  'CatalogProductsDto parses the v1 catalog response shape' \
  'home tab renders catalog products from the API repository' \
  'home tab exposes a retry state' \
  'without losing scroll state' \
  'nested navigation state'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'GET /catalog/search|/catalog/search|VisibilityDetector|device_info_plus|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|signed.?url|optimized GLB|Navigator.*product|cart persistence|Meilisearch|PostgreSQL|MinIO|NATS' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-031 must not add search UI, 360 activation, device-tier behavior, product detail, cart persistence, or direct backend service access" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-031 verification passed"
