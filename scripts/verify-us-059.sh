#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/apps/mobile-flutter"
CATALOG_VIEW="$APP_DIR/lib/features/catalog/presentation/catalog_products_view.dart"
CATEGORY_VIEW="$APP_DIR/lib/features/catalog/presentation/category_products_view.dart"
SPRITE_VIEW="$APP_DIR/lib/features/catalog/presentation/catalog_sprite_preview.dart"
WIDGET_TEST="$APP_DIR/test/widget_test.dart"
STORY="$ROOT/docs/stories/epics/E14-backend-cart/US-059-catalog-subtle-360-idle-preview.md"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command dart
require_command flutter
require_command grep

grep -q "US-059" "$ROOT/docs/product/mobile-commerce.md"
grep -q "Catalog Subtle 360 Idle Preview" "$ROOT/docs/product/roadmap.md"
grep -q "US-059" "$ROOT/docs/stories/backlog.md"
grep -q "crop a single product frame" "$ROOT/docs/product/mobile-commerce.md"
grep -q "CatalogSpriteFrame" "$SPRITE_VIEW"
grep -q "CatalogSubtleSpritePreview" "$SPRITE_VIEW"
grep -q "_subtlePreviewFrames = <int>\\[0, 1, 2, 1, 0, 23, 22, 23\\]" \
  "$SPRITE_VIEW"
grep -q "sprite-frame-" "$CATALOG_VIEW"
grep -q "subtle-preview-" "$CATALOG_VIEW"
grep -q "category-sprite-frame-" "$CATEGORY_VIEW"
grep -q "category-subtle-preview-" "$CATEGORY_VIEW"
grep -q "category tab uses the same subtle idle sprite preview" "$WIDGET_TEST"

if grep -R "_SpriteSheetPreview" "$CATALOG_VIEW" "$CATEGORY_VIEW" "$SPRITE_VIEW"; then
  echo "US-059 must remove the old full-cycle sprite sheet preview widget" >&2
  exit 1
fi

if grep -R -E "/checkout|/payment|/orders|/login|/auth|/inventory" \
  "$APP_DIR/lib" \
  "$WIDGET_TEST" \
  "$STORY"; then
  echo "US-059 must not introduce checkout, payment, order, auth, or inventory scope" >&2
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

echo "US-059 verification passed"
