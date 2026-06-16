#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-044" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-044.sh
bash -n apps/mobile-flutter/tools/bazel_flutter_check.sh

app_dir="apps/mobile-flutter"

for required_file in \
  "$app_dir/BUILD.bazel" \
  "$app_dir/tools/bazel_flutter_check.sh" \
  "docs/stories/epics/E08-mobile-shell/US-044-flutter-bazel-build-test-boundary.md"; do
  test -f "$required_file"
done

build_text="$(cat "$app_dir/BUILD.bazel")"
image_bazelrc_text="$(cat .bazelrc)"
runner_text="$(cat "$app_dir/tools/bazel_flutter_check.sh")"
story_text="$(cat docs/stories/epics/E08-mobile-shell/US-044-flutter-bazel-build-test-boundary.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"

for required in \
  'load(":flutter_validation_test.bzl", "flutter_validation_test")' \
  'name = "mobile-flutter-sources"' \
  'flutter_validation_test(' \
  'name = "mobile-flutter-test"' \
  'tools/bazel_flutter_check.sh' \
  '"local"' \
  '"no-sandbox"' \
  'timeout = "long"'; do
  grep -q "$required" <<<"$build_text"
done

for required in \
  'FLUTTER_HOME' \
  '$HOME/flutter/bin' \
  'TEST_TMPDIR' \
  'cp -R -L "$source_dir/." "$work_dir/"' \
  'flutter pub get' \
  'dart format --set-exit-if-changed lib test' \
  'flutter analyze' \
  'flutter test test/us040_capture_test.dart --update-goldens' \
  'flutter test'; do
  grep -q "$required" <<<"$runner_text"
done

for required in \
  'test --test_env=PATH' \
  'test --test_env=HOME' \
  'test --test_env=FLUTTER_HOME'; do
  grep -q "$required" <<<"$image_bazelrc_text"
done

for required in \
  'US-044 Flutter Bazel Build And Test Boundary' \
  'copies the app into a' \
  'This story does not add checkout, payments, authentication, authorization' \
  'bazel test //apps/mobile-flutter:mobile-flutter-test'; do
  grep -q "$required" <<<"$story_text"
done

grep -q 'US-044 Flutter Bazel Build And Test Boundary' <<<"$roadmap_text"
grep -q 'Bazel-owned validation boundary' <<<"$mobile_text"
grep -q 'US-044' <<<"$platform_text"
grep -q 'US-044 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-044.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-044.sh' <<<"$app_readme_text"

if grep -R -E -i 'checkout|payment|auth|inventory|signed.?url|PostgreSQL|MinIO|NATS|Meilisearch' \
  "$app_dir/tools" "$app_dir/BUILD.bazel"; then
  echo "US-044 must not add commerce behavior, auth, signed URLs, or direct backend service access" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

bazelisk build //apps/mobile-flutter:mobile-flutter-sources
bazelisk test //apps/mobile-flutter:mobile-flutter-test

echo "US-044 verification passed"
