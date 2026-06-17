#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-040" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-040.sh

app_dir="apps/mobile-flutter"
capture_file="reports/us-040/cart-local-persistence.png"

for required_file in \
  "$app_dir/lib/features/cart/domain/cart_item.dart" \
  "$app_dir/lib/features/cart/domain/cart_repository.dart" \
  "$app_dir/lib/features/cart/data/shared_preferences_cart_repository.dart" \
  "$app_dir/lib/features/cart/presentation/cubit/cart_cubit.dart" \
  "$app_dir/lib/features/cart/presentation/cart_view.dart" \
  "$app_dir/lib/features/catalog/presentation/product_detail_view.dart" \
  "$app_dir/lib/features/shell/presentation/shell_page.dart" \
  "$app_dir/test/widget_test.dart" \
  "docs/THIRD_PARTY_NOTICES.md" \
  "docs/stories/epics/E13-cart/US-040-flutter-local-cart-persistence.md"; do
  test -f "$required_file"
done

story_text="$(cat docs/stories/epics/E13-cart/US-040-flutter-local-cart-persistence.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
third_party_text="$(cat docs/THIRD_PARTY_NOTICES.md)"
pubspec_text="$(cat "$app_dir/pubspec.yaml")"
cart_repo_text="$(cat "$app_dir/lib/features/cart/data/shared_preferences_cart_repository.dart")"
cart_cubit_text="$(cat "$app_dir/lib/features/cart/presentation/cubit/cart_cubit.dart")"
cart_view_text="$(cat "$app_dir/lib/features/cart/presentation/cart_view.dart")"
detail_text="$(cat "$app_dir/lib/features/catalog/presentation/product_detail_view.dart")"
shell_text="$(cat "$app_dir/lib/features/shell/presentation/shell_page.dart")"
app_text="$(cat "$app_dir/lib/app/app.dart")"
test_text="$(cat "$app_dir"/test/*.dart)"

for required in \
  'US-040 Flutter Local Cart Persistence' \
  'locally persisted cart' \
  'product identity, selected mesh colors, quantity, and selection state' \
  'mobile-size Cart tab screenshot'; do
  grep -q "$required" <<<"$story_text"
done

for required in \
  'US-040 Flutter Local Cart Persistence' \
  'locally persisted cart' \
  'quantity, and selection state'; do
  grep -q "$required" <<<"$roadmap_text"
done

for required in \
  'US-040' \
  'locally persisted cart' \
  'selected mesh colors'; do
  grep -q "$required" <<<"$mobile_text"
done

grep -q 'US-040' <<<"$platform_text"
grep -q 'US-040 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-040.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-040.sh' <<<"$app_readme_text"
grep -q 'shared_preferences 2.5.5' <<<"$third_party_text"
grep -q 'shared_preferences:' <<<"$pubspec_text"

for required in \
  "import 'dart:convert'" \
  'SharedPreferencesAsync' \
  "'product_id'" \
  "'selected_colors'" \
  "'qty'" \
  "'selected'"; do
  grep -q "$required" <<<"$cart_repo_text"
done

for required in \
  'class CartCubit' \
  'addProduct' \
  'increment' \
  'decrement' \
  'toggleSelection' \
  '_sameSelectedColors'; do
  grep -q "$required" <<<"$cart_cubit_text"
done

for required in \
  'class CartView' \
  'Cart is empty' \
  'cart-summary' \
  'cart-item-' \
  'cart-qty-' \
  'selectedColors'; do
  grep -q "$required" <<<"$cart_view_text"
done

for required in \
  'Add to cart' \
  'add-selected-product-to-cart' \
  'context.read<CartCubit>().addProduct'; do
  grep -q "$required" <<<"$detail_text"
done

grep -Fq 'CartView' <<<"$shell_text"
grep -q 'SharedPreferencesCartRepository' <<<"$app_text"
grep -Fq 'CartCubit(cart)..load()' <<<"$app_text"

for required in \
  'product detail adds the selected configuration to the local cart' \
  'cart tab updates quantity and selection state' \
  'mesh_body: #0F172A'; do
  grep -q "$required" <<<"$test_text"
done

if grep -R -E -i 'postgres|nats|meilisearch|signed.?url|checkout|payment|inventory' \
  "$app_dir/lib" "$app_dir/test" "$app_dir/pubspec.yaml"; then
  echo "US-040 must not add direct backend service access, signed URLs, inventory, checkout, or payments" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test test/us040_capture_test.dart --update-goldens)
(cd "$app_dir" && flutter test)

if [[ -f "$capture_file" ]]; then
  test -s "$capture_file"
else
  echo "US-040 UI screenshot not found at $capture_file; capture the mobile Cart tab before final proof" >&2
  exit 1
fi

echo "US-040 verification passed"
