#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-035" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-035.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/pubspec.yaml" \
  "$app_dir/lib/features/catalog/domain/catalog_product.dart" \
  "$app_dir/lib/features/catalog/data/catalog_api_client.dart" \
  "$app_dir/lib/features/catalog/presentation/catalog_products_view.dart" \
  "$app_dir/test/catalog_api_client_test.dart" \
  "$app_dir/test/widget_test.dart" \
  "docs/stories/epics/E09-catalog-search/US-035-flutter-360-catalog-preview-activation.md"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E09-catalog-search/US-035-flutter-360-catalog-preview-activation.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
pubspec_text="$(cat "$app_dir/pubspec.yaml")"
domain_text="$(cat "$app_dir/lib/features/catalog/domain/catalog_product.dart")"
api_text="$(cat "$app_dir/lib/features/catalog/data/catalog_api_client.dart")"
view_text="$(cat "$app_dir/lib/features/catalog/presentation/catalog_products_view.dart")"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-035 Flutter 360 Catalog Preview Activation' \
  'at least 80% visible' \
  'three seconds' \
  'GET /catalog/products/{id}/sprite' \
  'does not add category taxonomy'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-035 Flutter 360 Catalog Preview Activation' \
  '80% visible' \
  'without adding category taxonomy'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-035' \
  'activates processed sprite previews' \
  'VisibilityDetector' \
  'MinIO directly'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-035' <<<"$platform_text"
grep -q 'US-035 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-035.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-035.sh' <<<"$app_readme_text"
grep -q 'visibility_detector:' <<<"$pubspec_text"

for required in \
  'spritePreviewUri' \
  'copyWith'; do
  grep -q "$required" <<<"$domain_text"
done

for required in \
  '_catalogSpriteUri' \
  'getUrl' \
  '/catalog/products/' \
  '/sprite' \
  'spritePreviewUriFor'; do
  grep -q "$required" <<<"$api_text"
done

for required in \
  'VisibilityDetector' \
  '_previewActivationDelay = Duration(seconds: 3)' \
  '_previewVisibilityThreshold = 0.8' \
  '_spriteFrameCount = 24' \
  '_spriteColumns = 6' \
  '_spriteRows = 4' \
  'Image.network' \
  'Scrollable.maybeOf' \
  '360 preview active'; do
  grep -q "$required" <<<"$view_text"
done

for required in \
  'home tab activates a visible idle 360 sprite preview' \
  'home tab cancels pending preview activation while scrolling' \
  'http://api.test/catalog/products/prod_2/sprite' \
  'VisibilityDetectorController' \
  'spritePreviewUriFor'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'MinIO|PostgreSQL|NATS|Meilisearch|signed.?url|device_info_plus|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|Navigator.*product|cart persistence|optimized GLB|GET .*lumin-360-sprites|http://.*minio' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-035 must not add direct backend service access, signed URLs, device-tier behavior, product detail, or cart persistence" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-035 verification passed"
