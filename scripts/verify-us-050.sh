#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in curl dart flutter jq xcrun; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-050" >&2
    exit 1
  fi
done

api_base_url="${LUMIN_US050_API_BASE_URL:-}"
if [[ -z "$api_base_url" ]]; then
  echo "LUMIN_US050_API_BASE_URL is required, for example http://127.0.0.1:8080" >&2
  exit 1
fi
api_base_url="${api_base_url%/}"

bash -n scripts/verify-us-050.sh

story_text="$(cat docs/stories/epics/E13-cart/US-050-live-flutter-customer-commerce-smoke.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
app_readme_text="$(cat apps/mobile-flutter/README.md)"
pubspec_text="$(cat apps/mobile-flutter/pubspec.yaml)"
integration_text="$(cat apps/mobile-flutter/integration_test/us050_live_customer_smoke_test.dart)"

for required in \
  'US-050 Live Flutter Customer Commerce Smoke' \
  'live simulator' \
  'LUMIN_US050_API_BASE_URL' \
  'authentication, authorization' \
  'checkout, payments'; do
  grep -q "$required" <<<"$story_text"
done

grep -q 'US-050 Live Flutter Customer Commerce Smoke' <<<"$roadmap_text"
grep -q 'US-050' <<<"$mobile_text"
grep -q 'US-050' <<<"$platform_text"
grep -q 'US-050 in progress' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-050.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-050.sh' <<<"$app_readme_text"
grep -q 'integration_test:' <<<"$pubspec_text"

for required in \
  'IntegrationTestWidgetsFlutterBinding.ensureInitialized' \
  'LUMIN_API_BASE_URL' \
  'FixedDeviceTierResolver' \
  'ProductModelTier.high' \
  'US-050 model viewer high' \
  'add-selected-product-to-cart' \
  'cart-summary'; do
  grep -q "$required" <<<"$integration_text"
done

if grep -Eqi 'checkout|payment|JWT|session|/login|DELETE /admin/products|POST /cart|signed.?url|PostgreSQL|MinIO|NATS|Meilisearch' \
  apps/mobile-flutter/integration_test/us050_live_customer_smoke_test.dart; then
  echo "US-050 integration test must not add checkout, payment, auth, signed URL, backend cart, delete, or direct platform access behavior" >&2
  exit 1
fi

catalog_response="$(mktemp)"
detail_response="$(mktemp)"
trap 'rm -f "$catalog_response" "$detail_response"' EXIT

curl -fsS "${api_base_url}/catalog/products?limit=50&offset=0" >"$catalog_response"
product_id="$(jq -r '.items[] | select(.processingStatus == "completed" and .spriteAsset != null and (.categories | length > 0)) | .id' "$catalog_response" | head -n 1)"
if [[ -z "$product_id" || "$product_id" == "null" ]]; then
  cat "$catalog_response" >&2
  echo "US-050 requires at least one completed catalog product with category metadata and a sprite asset" >&2
  exit 1
fi

product_name="$(jq -r --arg id "$product_id" '.items[] | select(.id == $id) | .name' "$catalog_response")"
category_name="$(jq -r --arg id "$product_id" '.items[] | select(.id == $id) | .categories[0].name' "$catalog_response")"

curl -fsS "${api_base_url}/catalog/products/${product_id}?tier=high" >"$detail_response"
jq -e --arg id "$product_id" \
  '.id == $id and .processingStatus == "completed" and .modelTier == "high" and .modelUrl == ("/catalog/products/" + $id + "/model?tier=high") and .spriteAsset != null and (.meshColorConfig | length > 0)' \
  "$detail_response" >/dev/null

mesh_id="$(jq -r '.meshColorConfig[0].meshId' "$detail_response")"
mesh_color="$(jq -r '.meshColorConfig[0].allowedColors[-1]' "$detail_response")"
if [[ -z "$mesh_id" || "$mesh_id" == "null" || -z "$mesh_color" || "$mesh_color" == "null" ]]; then
  cat "$detail_response" >&2
  echo "US-050 requires product detail mesh color configuration with at least one allowed color" >&2
  exit 1
fi

search_response="$(curl -fsS --get --data-urlencode "q=${product_name}" "${api_base_url}/catalog/search?limit=20&offset=0")"
jq -e --arg id "$product_id" '.items[] | select(.id == $id)' <<<"$search_response" >/dev/null

category_slug="$(jq -r --arg id "$product_id" '.items[] | select(.id == $id) | .categories[0].slug' "$catalog_response")"
category_response="$(curl -fsS "${api_base_url}/catalog/categories/${category_slug}/products?sort=newest&limit=20&offset=0")"
jq -e --arg id "$product_id" '.items[] | select(.id == $id)' <<<"$category_response" >/dev/null

(cd apps/mobile-flutter && flutter pub get)
(cd apps/mobile-flutter && dart format --set-exit-if-changed lib test integration_test)
(cd apps/mobile-flutter && flutter analyze)
(cd apps/mobile-flutter && flutter test)

device_id="${LUMIN_US050_DEVICE_ID:-}"
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available -j \
    | jq -r '[.devices[][] | select(.isAvailable == true and (.name | test("iPhone"))) | select(.state == "Booted")][0].udid // empty')"
fi
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available -j \
    | jq -r '[.devices[][] | select(.isAvailable == true and (.name | test("iPhone")))][0].udid // empty')"
fi
if [[ -z "$device_id" ]]; then
  echo "US-050 requires an available iPhone simulator or LUMIN_US050_DEVICE_ID" >&2
  exit 1
fi

xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b >/dev/null

(cd apps/mobile-flutter && flutter test integration_test/us050_live_customer_smoke_test.dart \
  -d "$device_id" \
  --dart-define="LUMIN_API_BASE_URL=${api_base_url}" \
  --dart-define="LUMIN_US050_PRODUCT_ID=${product_id}" \
  --dart-define="LUMIN_US050_PRODUCT_NAME=${product_name}" \
  --dart-define="LUMIN_US050_CATEGORY_NAME=${category_name}" \
  --dart-define="LUMIN_US050_MESH_ID=${mesh_id}" \
  --dart-define="LUMIN_US050_MESH_COLOR=${mesh_color}")

echo "US-050 verification passed for ${product_id}"
