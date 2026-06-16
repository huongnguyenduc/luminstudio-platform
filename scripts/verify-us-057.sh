#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

need dart
need flutter
need grep

grep -q "US-057" docs/product/mobile-commerce.md
grep -q "Catalog And Category Browse Ergonomics" docs/product/roadmap.md
grep -q "US-057 implemented" docs/stories/backlog.md
grep -q "sort choices" docs/stories/epics/E14-backend-cart/US-057-catalog-and-category-browse-ergonomics.md
grep -q "Browse \${products.length} products" apps/mobile-flutter/lib/features/catalog/presentation/catalog_products_view.dart
grep -q "Sorted by \${state.sort.label}" apps/mobile-flutter/lib/features/catalog/presentation/category_products_view.dart
grep -q "Sort products" apps/mobile-flutter/test/us055_ui_audit_capture_test.dart
grep -q "Price high to low" apps/mobile-flutter/test/widget_test.dart

if grep -R -E "/checkout|/payment|/orders|/login|/auth|/inventory" \
  apps/mobile-flutter/lib \
  apps/mobile-flutter/test/us055_ui_audit_capture_test.dart \
  docs/stories/epics/E14-backend-cart/US-057-catalog-and-category-browse-ergonomics.md; then
  echo "US-057 must not introduce deferred commerce/auth/inventory scope" >&2
  exit 1
fi

(
  cd apps/mobile-flutter
  flutter pub get
  dart format --set-exit-if-changed lib test
  flutter analyze
  flutter test test/us055_ui_audit_capture_test.dart --update-goldens
  flutter test
)

for shot in \
  reports/ui-ux-review/us055-home.png \
  reports/ui-ux-review/us055-category.png \
  reports/ui-ux-review/us055-detail-top.png \
  reports/ui-ux-review/us055-detail-customization.png \
  reports/ui-ux-review/us055-cart.png; do
  test -s "$shot"
done
