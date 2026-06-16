#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-030" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-030.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/pubspec.yaml" \
  "$app_dir/pubspec.lock" \
  "$app_dir/lib/main.dart" \
  "$app_dir/lib/app/app.dart" \
  "$app_dir/lib/features/shell/presentation/cubit/shell_cubit.dart" \
  "$app_dir/lib/features/shell/presentation/shell_page.dart" \
  "$app_dir/test/widget_test.dart" \
  "$app_dir/android/app/src/main/AndroidManifest.xml" \
  "$app_dir/ios/Runner/Info.plist"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E08-mobile-shell/US-030-flutter-customer-app-shell.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
pubspec_text="$(cat "$app_dir/pubspec.yaml")"
app_text="$(cat "$app_dir/lib/main.dart" "$app_dir/lib/app/app.dart")"
shell_text="$(cat "$app_dir/lib/features/shell/presentation/cubit/shell_cubit.dart" "$app_dir/lib/features/shell/presentation/shell_page.dart")"
test_text="$(cat "$app_dir/test/widget_test.dart")"

for required in \
  'US-030 Flutter Customer App Shell' \
  'Bottom navigation exposes Home, Category, and Cart tabs' \
  'does not add catalog API integration' \
  'flutter analyze' \
  'Flutter widget tests'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-030 Flutter Customer App Shell' \
  'Home, Category, and Cart' \
  'without adding catalog API integration'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'Bottom navigation exposes Home, Category, and Cart' \
  'Each tab retains its navigation and scroll state' \
  'US-030'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-030' <<<"$platform_text"
grep -q 'US-030 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-030.sh' <<<"$readme_text"
grep -q 'bash scripts/verify-us-030.sh' <<<"$app_readme_text"
grep -q 'flutter_bloc:' <<<"$pubspec_text"

for required in \
  'LuminStudioApp' \
  'BlocProvider' \
  'CustomerShellPage'; do
  grep -q "$required" <<<"$app_text"
done

for required in \
  'enum CustomerTab' \
  'class ShellCubit extends Cubit<ShellState>' \
  'NavigationBar' \
  'IndexedStack' \
  'Navigator(' \
  'PageStorageKey<String>' \
  'Semantics(' \
  'Home' \
  'Category' \
  'Cart'; do
  grep -q "$required" <<<"$shell_text"
done

for required in \
  'ShellCubit changes selected tab' \
  'customer shell exposes the three bottom navigation tabs' \
  'without losing scroll state' \
  'nested navigation state'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'GET /catalog|/catalog/products|/catalog/search|Meilisearch|VisibilityDetector|device_info_plus|shared_preferences|(^|[^a-z])hive($|[^a-z])|sqflite|optimized GLB|sprite asset' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-030 must not add catalog API integration, 360 preview, device-tier behavior, or cart persistence" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

echo "US-030 verification passed"
