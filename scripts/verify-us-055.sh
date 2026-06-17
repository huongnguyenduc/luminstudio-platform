#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-055" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-055.sh

app_dir="apps/mobile-flutter"
capture_test="$app_dir/test/us055_ui_audit_capture_test.dart"
story_file="docs/stories/epics/E14-backend-cart/US-055-flutter-ui-ux-audit-capture-harness.md"

for required_file in \
  "$capture_test" \
  "$story_file" \
  "docs/product/mobile-commerce.md" \
  "docs/product/roadmap.md" \
  "docs/stories/backlog.md"; do
  test -f "$required_file"
done

story_text="$(cat "$story_file")"
mobile_text="$(cat docs/product/mobile-commerce.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
backlog_text="$(cat docs/stories/backlog.md)"
capture_text="$(cat "$capture_test")"

for required in \
  'US-055 Flutter UI UX Audit Capture Harness' \
  'deterministic UI audit capture harness' \
  'does not change checkout, payments' \
  'reports/ui-ux-review/'; do
  grep -Fq "$required" <<<"$story_text"
done

grep -Fq 'US-055' <<<"$mobile_text"
grep -Fq 'US-055 Flutter UI UX Audit Capture Harness' <<<"$roadmap_text"
grep -Fq 'US-055 implemented' <<<"$backlog_text"

for required in \
  'captures US-055 Home audit screenshot' \
  'captures US-055 Category audit screenshot' \
  'captures US-055 Product Detail top audit screenshot' \
  'captures US-055 Product Detail customization audit screenshot' \
  'captures US-055 Cart audit screenshot' \
  'matchesGoldenFile' \
  '_AuditCatalogRepository' \
  '_AuditCartRepository' \
  'FixedDeviceTierResolver(ProductModelTier.high)' \
  'us055-home.png' \
  'us055-category.png' \
  'us055-detail-top.png' \
  'us055-detail-customization.png' \
  'us055-cart.png'; do
  grep -Fq "$required" <<<"$capture_text"
done

if grep -R -E -i '/checkout|/payment|/orders|/login|/auth|/inventory' \
  "$app_dir/lib" "$capture_test"; then
  echo "US-055 must not add checkout, payment, order, auth, or inventory routes" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test test/us055_ui_audit_capture_test.dart --update-goldens)
(cd "$app_dir" && flutter test)

for capture in \
  reports/ui-ux-review/us055-home.png \
  reports/ui-ux-review/us055-category.png \
  reports/ui-ux-review/us055-detail-top.png \
  reports/ui-ux-review/us055-detail-customization.png \
  reports/ui-ux-review/us055-cart.png; do
  test -s "$capture"
done

echo "US-055 verification passed"
