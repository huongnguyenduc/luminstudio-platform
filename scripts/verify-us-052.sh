#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk dart flutter grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-052" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-052.sh

app_dir="apps/mobile-flutter"
story_text="$(cat docs/stories/epics/E14-backend-cart/US-052-flutter-backend-cart-api-integration.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
overview_text="$(cat docs/product/overview.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat "$app_dir/README.md")"
cart_client_text="$(cat "$app_dir/lib/features/cart/data/cart_api_client.dart")"
cart_repo_text="$(cat "$app_dir/lib/features/cart/data/api_backed_cart_repository.dart")"
cart_store_text="$(cat "$app_dir/lib/features/cart/data/shared_preferences_cart_repository.dart")"
cart_view_text="$(cat "$app_dir/lib/features/cart/presentation/cart_view.dart")"
app_text="$(cat "$app_dir/lib/app/app.dart")"
cart_tests_text="$(cat "$app_dir/test/cart_api_client_test.dart" "$app_dir/test/widget_test.dart")"

for required in \
  'US-052 Flutter Backend Cart API Integration' \
  'POST /cart' \
  'GET /cart/{id}' \
  'PUT /cart/{id}' \
  'does not add checkout, payments'; do
  grep -Fq "$required" <<<"$story_text"
done

for source in "$roadmap_text" "$mobile_text" "$platform_text" "$admin_text" "$root_readme_text" "$app_readme_text"; do
  grep -Fq 'US-052' <<<"$source"
  grep -Fq 'POST /cart' <<<"$source"
done

grep -Fq 'backend-synchronized anonymous cart snapshots' <<<"$overview_text"
grep -Fq 'US-052 implemented' <<<"$backlog_text"
grep -Fq 'bash scripts/verify-us-052.sh' <<<"$root_readme_text"
grep -Fq 'bash scripts/verify-us-052.sh' <<<"$app_readme_text"

for required in \
  'class CartApiClient' \
  'createCart' \
  'getCart' \
  'updateCart' \
  'CartRecordDto' \
  'selectedAmountCents'; do
  grep -Fq "$required" <<<"$cart_client_text"
done

for required in \
  'class ApiBackedCartRepository' \
  'loadCartId' \
  'saveCartId' \
  'createCart(items)' \
  'updateCart(cartId, items)' \
  'localRepository.saveCart'; do
  grep -Fq "$required" <<<"$cart_repo_text"
done

for required in \
  'CartIdStore' \
  'lumin.cart.id.v1' \
  'saveCartId'; do
  grep -Fq "$required" <<<"$cart_store_text"
done

for required in \
  'ApiBackedCartRepository' \
  'CartApiClient(baseUri: apiBaseUri)' \
  'SharedPreferencesCartRepository'; do
  grep -Fq "$required" <<<"$app_text"
done

for required in \
  'cart-sync-progress' \
  'Syncing cart'; do
  grep -Fq "$required" <<<"$cart_view_text"
done

for required in \
  'CartApiClient posts the v1 cart upsert shape' \
  'ApiBackedCartRepository syncs backend records' \
  'falls back to local cache' \
  'cart tab shows backend sync state'; do
  grep -Fq "$required" <<<"$cart_tests_text"
done

if grep -R -E -i 'PostgreSQL|MinIO|NATS|Meilisearch' \
  "$app_dir/lib" "$app_dir/test"; then
  echo "US-052 must keep Flutter behind the Go API boundary" >&2
  exit 1
fi

if grep -R -E -i '/checkout|/payment|/orders|/login|/auth|/inventory' "$app_dir/lib"; then
  echo "US-052 must not add checkout, payment, order, auth, or inventory routes" >&2
  exit 1
fi

(cd "$app_dir" && flutter pub get)
(cd "$app_dir" && dart format --set-exit-if-changed lib test)
(cd "$app_dir" && flutter analyze)
(cd "$app_dir" && flutter test)

bazelisk build //apps/mobile-flutter:mobile-flutter-sources
bazelisk test //apps/mobile-flutter:mobile-flutter-test

echo "US-052 verification passed"
