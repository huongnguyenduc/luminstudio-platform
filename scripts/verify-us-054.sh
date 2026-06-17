#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-054" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-054.sh

story_text="$(cat docs/stories/epics/E14-backend-cart/US-054-flutter-customer-ui-ux-polish.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
backlog_text="$(cat docs/stories/backlog.md)"
ui_skills_text="$(cat docs/UI_SKILLS.md)"
register_text="$(cat scripts/register-ui-skills.sh)"
catalog_text="$(cat apps/mobile-flutter/lib/features/catalog/presentation/catalog_products_view.dart)"
detail_text="$(cat apps/mobile-flutter/lib/features/catalog/presentation/product_detail_view.dart)"
cart_text="$(cat apps/mobile-flutter/lib/features/cart/presentation/cart_view.dart)"
widget_test_text="$(cat apps/mobile-flutter/test/widget_test.dart)"

for required in \
  'US-054 Flutter Customer UI UX Polish' \
  'does not add checkout, payments' \
  'redesign-existing-projects' \
  'flutter-expert'; do
  grep -Fq "$required" <<<"$story_text"
done

grep -Fq 'US-054' <<<"$mobile_text"
grep -Fq 'US-054' <<<"$roadmap_text"
grep -Fq 'US-054 implemented' <<<"$backlog_text"
grep -Fq '.codex/skills' <<<"$ui_skills_text"
grep -Fq '.codex/skills/redesign-existing-projects/SKILL.md' <<<"$register_text"
grep -Fq '.codex/skills/flutter-expert/SKILL.md' <<<"$register_text"

for required in \
  '_ProductStatusPill' \
  '_formatMoney' \
  'product.price.amountCents' \
  'categoryLabel'; do
  grep -Fq "$required" <<<"$catalog_text"
done

for required in \
  '_ProductDetailBottomBar' \
  'Customize color' \
  '_friendlyMeshName' \
  'find.textContaining('\''/catalog/products/prod_1/model'\'')'; do
  grep -Fq "$required" <<<"$detail_text$widget_test_text"
done

for required in \
  'Cart summary' \
  '_CartColorChip' \
  'Quantity' \
  'Body: #0F172A'; do
  grep -Fq "$required" <<<"$cart_text$widget_test_text"
done

if grep -Fq 'Model route:' apps/mobile-flutter/lib/features/catalog/presentation/product_detail_view.dart; then
  echo "US-054 must not expose internal model routes in Product Detail UI" >&2
  exit 1
fi
if grep -Fq 'Sprite route:' apps/mobile-flutter/lib/features/catalog/presentation/product_detail_view.dart; then
  echo "US-054 must not expose internal sprite routes in Product Detail UI" >&2
  exit 1
fi
if grep -R -E -i '/checkout|/payment|/orders|/login|/auth|/inventory' apps/mobile-flutter/lib; then
  echo "US-054 must not add checkout, payment, order, auth, or inventory routes" >&2
  exit 1
fi

(cd apps/mobile-flutter && flutter analyze)
(cd apps/mobile-flutter && flutter test)

echo "US-054 verification passed"
