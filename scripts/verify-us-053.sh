#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in curl dart flutter jq xcrun; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-053" >&2
    exit 1
  fi
done

api_base_url="${LUMIN_US053_API_BASE_URL:-}"
if [[ -z "$api_base_url" ]]; then
  echo "LUMIN_US053_API_BASE_URL is required, for example http://127.0.0.1:8080" >&2
  exit 1
fi
api_base_url="${api_base_url%/}"

bash -n scripts/verify-us-053.sh

story_text="$(cat docs/stories/epics/E14-backend-cart/US-053-live-flutter-backend-cart-sync-smoke.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat apps/mobile-flutter/README.md)"
integration_text="$(cat apps/mobile-flutter/integration_test/us053_live_backend_cart_sync_test.dart)"

for required in \
  'US-053 Live Flutter Backend Cart Sync Smoke' \
  'live simulator proof' \
  'POST /cart' \
  'GET /cart/{id}' \
  'PUT /cart/{id}' \
  'does not add checkout, payments'; do
  grep -Fq "$required" <<<"$story_text"
done

for source in "$roadmap_text" "$mobile_text" "$platform_text" "$admin_text" "$root_readme_text" "$app_readme_text"; do
  grep -Fq 'US-053' <<<"$source"
done
grep -Fq 'US-053 implemented' <<<"$backlog_text"
grep -Fq 'bash scripts/verify-us-053.sh' <<<"$root_readme_text"
grep -Fq 'bash scripts/verify-us-053.sh' <<<"$app_readme_text"

for required in \
  'IntegrationTestWidgetsFlutterBinding.ensureInitialized' \
  'LUMIN_API_BASE_URL' \
  'LUMIN_US053_PRODUCT_ID' \
  'lumin.cart.id.v1' \
  'CartApiClient' \
  'getCart(cartId)' \
  'updateCart(cartId' \
  'US-053 model viewer' \
  'cart-qty-'; do
  grep -Fq "$required" <<<"$integration_text"
done

if grep -Eqi 'checkout|payment|JWT|session|/login|DELETE /admin/products|signed.?url|PostgreSQL|MinIO|NATS|Meilisearch' \
  apps/mobile-flutter/integration_test/us053_live_backend_cart_sync_test.dart; then
  echo "US-053 integration test must not add checkout, payment, auth, signed URL, delete, or direct platform access behavior" >&2
  exit 1
fi

catalog_response="$(mktemp)"
detail_response="$(mktemp)"
cart_request="$(mktemp)"
cart_create_response="$(mktemp)"
cart_get_response="$(mktemp)"
cart_update_request="$(mktemp)"
cart_update_response="$(mktemp)"
trap 'rm -f "$catalog_response" "$detail_response" "$cart_request" "$cart_create_response" "$cart_get_response" "$cart_update_request" "$cart_update_response"' EXIT

curl -fsS "${api_base_url}/catalog/products?limit=20&offset=0" >"$catalog_response"
product_id="$(jq -r '.items[] | select(.processingStatus == "completed" and .spriteAsset != null and (.categories | length > 0) and .price.amountCents > 0) | .id' "$catalog_response" | head -n 1)"
if [[ -z "$product_id" || "$product_id" == "null" ]]; then
  cat "$catalog_response" >&2
  echo "US-053 requires at least one completed catalog product with category, price, and sprite metadata" >&2
  exit 1
fi

product_name="$(jq -r --arg id "$product_id" '.items[] | select(.id == $id) | .name' "$catalog_response")"
curl -fsS "${api_base_url}/catalog/products/${product_id}?tier=high" >"$detail_response"
jq -e --arg id "$product_id" \
  '.id == $id and .processingStatus == "completed" and .modelTier == "high" and .price.amountCents > 0 and (.meshColorConfig | length > 0)' \
  "$detail_response" >/dev/null

mesh_id="$(jq -r '.meshColorConfig | to_entries[0].key' "$detail_response")"
mesh_color="$(jq -r '.meshColorConfig | to_entries[0].value.allowed[-1]' "$detail_response")"
if [[ -z "$mesh_id" || "$mesh_id" == "null" || -z "$mesh_color" || "$mesh_color" == "null" ]]; then
  cat "$detail_response" >&2
  echo "US-053 requires product detail mesh color configuration with at least one allowed color" >&2
  exit 1
fi

jq -n \
  --arg productId "$product_id" \
  --arg meshId "$mesh_id" \
  --arg meshColor "$mesh_color" \
  '{items: [{productId: $productId, selectedColors: {($meshId): $meshColor}, quantity: 1, selected: true}]}' \
  >"$cart_request"

curl -fsS -X POST \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data @"$cart_request" \
  "${api_base_url}/cart" >"$cart_create_response"
cart_id="$(jq -r '.id' "$cart_create_response")"
test "$cart_id" != "null"
jq -e --arg id "$product_id" --arg meshId "$mesh_id" --arg meshColor "$mesh_color" \
  '.items[0].productId == $id and .items[0].selectedColors[$meshId] == $meshColor and .items[0].quantity == 1 and .totals.selectedQuantity == 1' \
  "$cart_create_response" >/dev/null

curl -fsS "${api_base_url}/cart/${cart_id}" >"$cart_get_response"
jq -e --arg id "$product_id" '.items[0].productId == $id and .items[0].quantity == 1' "$cart_get_response" >/dev/null

jq --arg productId "$product_id" --arg meshId "$mesh_id" --arg meshColor "$mesh_color" \
  '.items = [{productId: $productId, selectedColors: {($meshId): $meshColor}, quantity: 2, selected: true}]' \
  "$cart_request" >"$cart_update_request"
curl -fsS -X PUT \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data @"$cart_update_request" \
  "${api_base_url}/cart/${cart_id}" >"$cart_update_response"
jq -e --arg id "$product_id" '.items[0].productId == $id and .items[0].quantity == 2 and .totals.selectedQuantity == 2' "$cart_update_response" >/dev/null

(cd apps/mobile-flutter && flutter pub get)
(cd apps/mobile-flutter && dart format --set-exit-if-changed lib test integration_test)
(cd apps/mobile-flutter && flutter analyze)
(cd apps/mobile-flutter && flutter test)

device_id="${LUMIN_US053_DEVICE_ID:-}"
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available -j \
    | jq -r '[.devices[][] | select(.isAvailable == true and (.name | test("iPhone"))) | select(.state == "Booted")][0].udid // empty')"
fi
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available -j \
    | jq -r '[.devices[][] | select(.isAvailable == true and (.name | test("iPhone")))][0].udid // empty')"
fi
if [[ -z "$device_id" ]]; then
  echo "US-053 requires an available iPhone simulator or LUMIN_US053_DEVICE_ID" >&2
  exit 1
fi

xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b >/dev/null

(cd apps/mobile-flutter && flutter test integration_test/us053_live_backend_cart_sync_test.dart \
  -d "$device_id" \
  --dart-define="LUMIN_API_BASE_URL=${api_base_url}" \
  --dart-define="LUMIN_US053_PRODUCT_ID=${product_id}" \
  --dart-define="LUMIN_US053_PRODUCT_NAME=${product_name}" \
  --dart-define="LUMIN_US053_MESH_ID=${mesh_id}" \
  --dart-define="LUMIN_US053_MESH_COLOR=${mesh_color}")

echo "US-053 verification passed for ${product_id}"
