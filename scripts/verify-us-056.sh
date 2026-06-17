#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/apps/mobile-flutter"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command dart
require_command flutter
require_command grep

grep -q "US-056" "$ROOT/docs/product/mobile-commerce.md"
grep -q "Product Detail Customize To Cart Ergonomics" "$ROOT/docs/product/roadmap.md"
grep -q "US-056 implemented" "$ROOT/docs/stories/backlog.md"
grep -q "mobile-responsive 3D viewer height" \
  "$ROOT/docs/stories/epics/E14-backend-cart/US-056-product-detail-customize-to-cart-ergonomics.md"
grep -q "Selected finish" \
  "$APP_DIR/lib/features/catalog/presentation/product_detail_view.dart"
grep -q "Body #0F172A" "$APP_DIR/test/widget_test.dart"
grep -q "Selected finish" "$APP_DIR/test/us055_ui_audit_capture_test.dart"

if grep -R -E "/checkout|/payment|/orders|/login|/auth|/inventory" \
  "$APP_DIR/lib" \
  "$APP_DIR/test/us055_ui_audit_capture_test.dart" \
  "$ROOT/docs/stories/epics/E14-backend-cart/US-056-product-detail-customize-to-cart-ergonomics.md"; then
  echo "US-056 must not introduce checkout, payment, order, auth, or inventory scope" >&2
  exit 1
fi

(
  cd "$APP_DIR"
  flutter pub get
  dart format --set-exit-if-changed lib test
  flutter analyze
  flutter test test/us055_ui_audit_capture_test.dart --update-goldens
  flutter test
)

for artifact in \
  us055-home.png \
  us055-category.png \
  us055-detail-top.png \
  us055-detail-customization.png \
  us055-cart.png; do
  test -s "$ROOT/reports/ui-ux-review/$artifact"
done

echo "US-056 verification passed"
