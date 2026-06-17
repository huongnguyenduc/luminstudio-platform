#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-037" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-037.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/lib/app/app.dart" \
  "$app_dir/lib/features/catalog/domain/catalog_product.dart" \
  "$app_dir/lib/features/catalog/domain/catalog_repository.dart" \
  "$app_dir/lib/features/catalog/domain/device_tier.dart" \
  "$app_dir/lib/features/catalog/domain/get_catalog_product_detail.dart" \
  "$app_dir/lib/features/catalog/data/catalog_api_client.dart" \
  "$app_dir/lib/features/catalog/data/http_catalog_repository.dart" \
  "$app_dir/lib/features/catalog/presentation/catalog_products_view.dart" \
  "$app_dir/lib/features/catalog/presentation/cubit/product_detail_cubit.dart" \
  "$app_dir/lib/features/catalog/presentation/product_detail_view.dart" \
  "$app_dir/test/catalog_api_client_test.dart" \
  "$app_dir/test/widget_test.dart" \
  "docs/stories/epics/E11-3d-detail/US-037-flutter-product-detail-and-device-tier-integration.md"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E11-3d-detail/US-037-flutter-product-detail-and-device-tier-integration.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
app_text="$(cat "$app_dir/lib/app/app.dart")"
domain_text="$(cat "$app_dir/lib/features/catalog/domain/catalog_product.dart" "$app_dir/lib/features/catalog/domain/device_tier.dart" "$app_dir/lib/features/catalog/domain/get_catalog_product_detail.dart" "$app_dir/lib/features/catalog/domain/catalog_repository.dart")"
api_text="$(cat "$app_dir/lib/features/catalog/data/catalog_api_client.dart" "$app_dir/lib/features/catalog/data/http_catalog_repository.dart")"
view_text="$(cat "$app_dir/lib/features/catalog/presentation/catalog_products_view.dart" "$app_dir/lib/features/catalog/presentation/product_detail_view.dart" "$app_dir/lib/features/catalog/presentation/cubit/product_detail_cubit.dart")"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-037 Flutter Product Detail And Device Tier Integration' \
  'GET /catalog/products/{id}?tier=low|high' \
  'The Flutter customer app opens a product detail screen' \
  'does not add an interactive Flutter 3D viewer'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-037 Flutter Product Detail And Device Tier Integration' \
  'device tier' \
  'without adding an interactive 3D viewer'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-037' \
  'opens a detail screen' \
  'selected model tier' \
  'direct service access remain deferred'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-037' <<<"$platform_text"
grep -q 'US-037 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-037.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-037.sh' <<<"$app_readme_text"

for required in \
  'RepositoryProvider<CatalogRepository>' \
  'RepositoryProvider<DeviceTierResolver>'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  'enum ProductModelTier' \
  'class CatalogProductDetail' \
  'class CatalogInformationSection' \
  'class CatalogMeshColorOptions' \
  'abstract interface class DeviceTierResolver' \
  'class DefaultDeviceTierResolver' \
  'class GetCatalogProductDetail' \
  'getProductDetail'; do
  grep -q "$required" <<<"$domain_text"
done

for required in \
  'Future<CatalogProductDetail> getProductDetail' \
  "'tier': tier.wireName" \
  'ProductDetailDto.fromJson' \
  'meshColorConfig' \
  'informationSections' \
  '_catalogRouteUri'; do
  grep -q "$required" <<<"$api_text"
done

for required in \
  'ProductDetailCubit' \
  'ProductDetailPage' \
  'Model tier:' \
  'Configurable colors' \
  'Navigator.of(context).push' \
  'GetCatalogProductDetail' \
  'DeviceTierResolver'; do
  grep -q "$required" <<<"$view_text"
done

for required in \
  'ProductDetailDto parses the v1 product detail response shape' \
  'ProductDetailDto rejects malformed product detail responses' \
  'home tab opens product detail with the resolved model tier' \
  'product detail exposes failure and retry states' \
  'home tab retains product detail route when switching tabs' \
  'FixedDeviceTierResolver'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'postgres|nats|meilisearch|signed.?url|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|checkout|payment' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-037 must not add direct backend service access, signed URLs, cart persistence, checkout, or payments" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-037 verification passed"
