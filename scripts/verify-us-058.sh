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

grep -q "US-058" "$ROOT/docs/product/mobile-commerce.md"
grep -q "Flutter Premium Visual System Refresh" "$ROOT/docs/product/roadmap.md"
grep -q "US-058 implemented" "$ROOT/docs/stories/backlog.md"
grep -q "premium studio-commerce theme" \
  "$ROOT/docs/product/mobile-commerce.md"
grep -q "imagegen-frontend-mobile" \
  "$ROOT/docs/stories/epics/E14-backend-cart/US-058-flutter-premium-visual-system-refresh.md"
grep -q "_luminTheme" "$APP_DIR/lib/app/app.dart"
grep -q "_ProductMediaTile" \
  "$APP_DIR/lib/features/catalog/presentation/catalog_products_view.dart"
grep -q "_CategoryProductMediaTile" \
  "$APP_DIR/lib/features/catalog/presentation/category_products_view.dart"
grep -q "screenHeight \\* 0.30" \
  "$APP_DIR/lib/features/catalog/presentation/product_detail_view.dart"
grep -q "cart-summary" "$APP_DIR/lib/features/cart/presentation/cart_view.dart"
grep -q "US-055 Home audit screenshot" \
  "$APP_DIR/test/us055_ui_audit_capture_test.dart"

if grep -R -E "/checkout|/payment|/orders|/login|/auth|/inventory" \
  "$APP_DIR/lib" \
  "$APP_DIR/test/us055_ui_audit_capture_test.dart" \
  "$ROOT/docs/stories/epics/E14-backend-cart/US-058-flutter-premium-visual-system-refresh.md"; then
  echo "US-058 must not introduce checkout, payment, order, auth, or inventory scope" >&2
  exit 1
fi

(
  cd "$APP_DIR"
  flutter pub get
  dart format --set-exit-if-changed lib test
  flutter analyze
  flutter test test/us040_capture_test.dart --update-goldens
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

test -s "$ROOT/reports/us-040/cart-local-persistence.png"

echo "US-058 verification passed"
