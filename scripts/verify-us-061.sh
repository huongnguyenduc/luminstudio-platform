#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/mobile-flutter"
API_DIR="$ROOT_DIR/services/api-gateway"

grep -Fq "US-061" "$ROOT_DIR/docs/product/mobile-commerce.md"
grep -Fq "Product Detail Finish Label Contract" "$ROOT_DIR/docs/product/roadmap.md"
grep -Fq "US-061 implemented" "$ROOT_DIR/docs/stories/backlog.md"
grep -Fq "Product Detail Finish Label Contract" \
  "$ROOT_DIR/docs/stories/epics/E14-backend-cart/US-061-product-detail-finish-label-contract.md"

grep -Fq '"labels"' "$ROOT_DIR/packages/shared-types/contracts/v1/common.schema.json"
grep -Fq "finish colors" "$ROOT_DIR/packages/shared-types/contracts/v1/README.md"

PRODUCT_MODEL="$API_DIR/internal/product/model.go"
PRODUCT_TEST="$API_DIR/internal/product/model_test.go"
CATALOG_TEST="$API_DIR/internal/search/catalog_test.go"
FLUTTER_DOMAIN="$APP_DIR/lib/features/catalog/domain/catalog_product.dart"
FLUTTER_CLIENT="$APP_DIR/lib/features/catalog/data/catalog_api_client.dart"
DETAIL_VIEW="$APP_DIR/lib/features/catalog/presentation/product_detail_view.dart"
FLUTTER_API_TEST="$APP_DIR/test/catalog_api_client_test.dart"
WIDGET_TEST="$APP_DIR/test/widget_test.dart"

grep -Fq "Labels  map[string]string" "$PRODUCT_MODEL"
grep -Fq "label color must be in allowed" "$PRODUCT_MODEL"
grep -Fq "empty label" "$PRODUCT_TEST"
grep -Fq "Porcelain white" "$CATALOG_TEST"
grep -Fq "final Map<String, String> colorLabels" "$FLUTTER_DOMAIN"
grep -Fq "String? labelForColor" "$FLUTTER_DOMAIN"
grep -Fq "_parseColorLabels" "$FLUTTER_CLIENT"
grep -Fq "_finishNameForOptions" "$DETAIL_VIEW"
grep -Fq "Chalk ceramic" "$FLUTTER_API_TEST"
grep -Fq "Body Chalk ceramic" "$WIDGET_TEST"
grep -Fq "Body Deep navy" "$WIDGET_TEST"

if grep -R -n "checkout\|payment\|auth\|inventory" \
  "$API_DIR/internal/product/model.go" \
  "$APP_DIR/lib/features/catalog" \
  "$APP_DIR/test/catalog_api_client_test.dart" \
  "$APP_DIR/test/widget_test.dart" \
  "$APP_DIR/test/us055_ui_audit_capture_test.dart"; then
  echo "US-061 regression: forbidden commerce scope appeared"
  exit 1
fi

node -e "const fs=require('fs'); JSON.parse(fs.readFileSync(process.argv[1], 'utf8'))" \
  "$ROOT_DIR/packages/shared-types/contracts/v1/common.schema.json"
node -e "const fs=require('fs'); JSON.parse(fs.readFileSync(process.argv[1], 'utf8'))" \
  "$ROOT_DIR/packages/shared-types/contracts/v1/product.schema.json"

cd "$API_DIR"
go test ./...

cd "$APP_DIR"
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/catalog_api_client_test.dart
flutter test test/widget_test.dart
flutter test test/us055_ui_audit_capture_test.dart --update-goldens
flutter test

test -s "$ROOT_DIR/reports/ui-ux-review/us055-detail-top.png"
test -s "$ROOT_DIR/reports/ui-ux-review/us055-detail-customization.png"

echo "US-061 verification passed"
