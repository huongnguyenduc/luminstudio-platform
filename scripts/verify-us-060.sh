#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/mobile-flutter"

grep -Fq "US-060" "$ROOT_DIR/docs/product/mobile-commerce.md"
grep -Fq "model panel is now materially larger" "$ROOT_DIR/docs/product/mobile-commerce.md"
grep -Fq "US-060 Product Detail Model First Finish Polish" "$ROOT_DIR/docs/product/roadmap.md"
grep -Fq "US-060 implemented" "$ROOT_DIR/docs/stories/backlog.md"
grep -Fq "Product Detail Model First Finish Polish" \
  "$ROOT_DIR/docs/stories/epics/E14-backend-cart/US-060-product-detail-model-first-finish-polish.md"

DETAIL_VIEW="$APP_DIR/lib/features/catalog/presentation/product_detail_view.dart"
WIDGET_TEST="$APP_DIR/test/widget_test.dart"
AUDIT_TEST="$APP_DIR/test/us055_ui_audit_capture_test.dart"

grep -Fq "final panelHeight = (screenHeight * 0.38).clamp(300.0, 420.0);" "$DETAIL_VIEW"
grep -Fq "class _ProductModelMetadata" "$DETAIL_VIEW"
grep -Fq "product-detail-model-tier" "$DETAIL_VIEW"
grep -Fq "Porcelain white" "$DETAIL_VIEW"
grep -Fq "Midnight navy" "$DETAIL_VIEW"
grep -Fq "selected-finish-\${options.meshId}" "$DETAIL_VIEW"

if grep -Fq "class _HighlightChip" "$DETAIL_VIEW"; then
  echo "US-060 regression: Product Detail still uses large highlight chips"
  exit 1
fi

if grep -Fq "class _SelectedConfigurationSummary" "$DETAIL_VIEW"; then
  echo "US-060 regression: redundant Selected finish summary still exists"
  exit 1
fi

grep -Fq "find.text('HIGH model')" "$WIDGET_TEST"
grep -Fq "find.text('Selected finish'), findsNothing" "$WIDGET_TEST"
grep -Fq "Body Chalk ceramic" "$WIDGET_TEST"
grep -Fq "Body Deep navy" "$WIDGET_TEST"
grep -Fq "find.text('HIGH model')" "$AUDIT_TEST"

if grep -R -n "checkout\|payment\|auth\|inventory" \
  "$APP_DIR/lib/features/catalog/presentation/product_detail_view.dart" \
  "$APP_DIR/test/widget_test.dart" \
  "$APP_DIR/test/us055_ui_audit_capture_test.dart"; then
  echo "US-060 regression: forbidden commerce scope appeared in Flutter detail changes"
  exit 1
fi

cd "$APP_DIR"
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/us055_ui_audit_capture_test.dart --update-goldens
flutter test

test -s "$ROOT_DIR/reports/ui-ux-review/us055-detail-top.png"
test -s "$ROOT_DIR/reports/ui-ux-review/us055-detail-customization.png"

echo "US-060 verification passed"
