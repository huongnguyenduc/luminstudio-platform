#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-039" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-039.sh

app_dir="apps/mobile-flutter"
capture_file="reports/us-039/product-detail-material-selection.png"

for required_file in \
  "$app_dir/lib/features/catalog/presentation/cubit/product_detail_cubit.dart" \
  "$app_dir/lib/features/catalog/presentation/product_detail_view.dart" \
  "$app_dir/test/widget_test.dart" \
  "docs/THIRD_PARTY_NOTICES.md" \
  "docs/stories/epics/E12-product-configuration/US-039-flutter-material-color-selection.md"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E12-product-configuration/US-039-flutter-material-color-selection.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
third_party_text="$(cat docs/THIRD_PARTY_NOTICES.md)"
cubit_text="$(cat "$app_dir/lib/features/catalog/presentation/cubit/product_detail_cubit.dart")"
api_client_text="$(cat "$app_dir/lib/features/catalog/data/catalog_api_client.dart")"
device_tier_text="$(cat "$app_dir/lib/features/catalog/domain/device_tier.dart")"
detail_text="$(cat "$app_dir/lib/features/catalog/presentation/product_detail_view.dart")"
pubspec_text="$(cat "$app_dir/pubspec.yaml")"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-039 Flutter Material Color Selection' \
  'select material colors' \
  'ProductDetailCubit' \
  'mobile-size Product Detail screenshot'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-039 Flutter Material Color Selection' \
  'selected colors' \
  'ProductDetailCubit'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-039' \
  'customer-selectable' \
  'selected color map'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-039' <<<"$platform_text"
grep -q 'US-039 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-039.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-039.sh' <<<"$app_readme_text"
grep -q 'http 1.6.0' <<<"$third_party_text"
grep -q 'BSD-3-' <<<"$third_party_text"
grep -q 'http:' <<<"$pubspec_text"

for required in \
  "import 'package:http/http.dart' as http" \
  'http.Client' \
  '_httpClient.get'; do
  grep -q "$required" <<<"$api_client_text"
done

for required in \
  "import 'package:flutter/foundation.dart'" \
  'kIsWeb' \
  'ProductModelTier.low'; do
  grep -q "$required" <<<"$device_tier_text"
done

for required in \
  'selectedMeshColors' \
  'selectMeshColor' \
  '_defaultMeshColors' \
  'allowedColors.contains(color)'; do
  grep -q "$required" <<<"$cubit_text"
done

for required in \
  '_MeshColorOptions' \
  '_ColorSwatch' \
  'mesh-color-' \
  'Semantics(' \
  'selected: isSelected' \
  'selectMeshColor(meshId, color)' \
  'AnimatedContainer'; do
  grep -q "$required" <<<"$detail_text"
done

for required in \
  'product detail lets customers select configured mesh colors' \
  'mesh_body color #0F172A selected'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'postgres|nats|meilisearch|signed.?url|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|checkout|payment' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-039 must not add direct backend service access, signed URLs, cart persistence, checkout, or payments" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

if [[ -f "$capture_file" ]]; then
  test -s "$capture_file"
else
  echo "US-039 UI screenshot not found at $capture_file; run the mobile browser capture before final proof" >&2
  exit 1
fi

echo "US-039 verification passed"
