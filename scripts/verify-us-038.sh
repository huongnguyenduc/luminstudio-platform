#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-038" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-038.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/pubspec.yaml" \
  "$app_dir/android/app/src/main/AndroidManifest.xml" \
  "$app_dir/lib/app/app.dart" \
  "$app_dir/lib/features/catalog/presentation/product_detail_view.dart" \
  "$app_dir/lib/features/catalog/presentation/product_model_viewer.dart" \
  "$app_dir/test/widget_test.dart" \
  "docs/THIRD_PARTY_NOTICES.md" \
  "docs/stories/epics/E11-3d-detail/US-038-flutter-interactive-3d-viewer.md"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E11-3d-detail/US-038-flutter-interactive-3d-viewer.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
third_party_text="$(cat docs/THIRD_PARTY_NOTICES.md)"
pubspec_text="$(cat "$app_dir/pubspec.yaml")"
manifest_text="$(cat "$app_dir/android/app/src/main/AndroidManifest.xml")"
app_text="$(cat "$app_dir/lib/app/app.dart")"
viewer_text="$(cat "$app_dir/lib/features/catalog/presentation/product_model_viewer.dart")"
detail_text="$(cat "$app_dir/lib/features/catalog/presentation/product_detail_view.dart")"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-038 Flutter Interactive 3D Viewer' \
  'interactive 3D viewer' \
  'modelUrl' \
  'does not add material color editing'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-038 Flutter Interactive 3D Viewer' \
  'rotate and zoom controls' \
  'material color editing'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-038' \
  'gateway `modelUrl`' \
  'rotate plus zoom controls'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-038' <<<"$platform_text"
grep -q 'US-038 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-038.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-038.sh' <<<"$app_readme_text"
grep -q 'model_viewer_plus 1.9.3' <<<"$third_party_text"
grep -q 'Apache-2.0' <<<"$third_party_text"

grep -q 'model_viewer_plus:' <<<"$pubspec_text"
grep -q 'android:usesCleartextTraffic="true"' <<<"$manifest_text"

for required in \
  'ProductModelViewerBuilder' \
  'defaultProductModelViewerBuilder' \
  'RepositoryProvider<ProductModelViewerBuilder>'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  "import 'package:model_viewer_plus/model_viewer_plus.dart'" \
  'class ProductModelViewer' \
  'ModelViewer(' \
  'src: modelUri.toString()' \
  'cameraControls: true' \
  'disableZoom: false' \
  'ar: false' \
  '3D model unavailable'; do
  grep -q "$required" <<<"$viewer_text"
done

for required in \
  '_InteractiveModelPanel' \
  'product-model-panel-' \
  'context.read<ProductModelViewerBuilder>()'; do
  grep -q "$required" <<<"$detail_text"
done

for required in \
  'product detail renders the injected interactive model viewer' \
  'product detail renders unavailable model state without a model route' \
  'productModelViewerBuilder: _fakeProductModelViewerBuilder'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'postgres|nats|meilisearch|signed.?url|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|checkout|payment' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-038 must not add direct backend service access, signed URLs, cart persistence, checkout, or payments" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-038 verification passed"
