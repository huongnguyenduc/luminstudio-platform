#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk cargo curl docker go jq k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-049" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n scripts/verify-us-049.sh

story_text="$(cat docs/stories/epics/E09-catalog-search/US-049-live-processed-product-catalog-smoke.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
mobile_text="$(cat docs/product/mobile-commerce.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
backlog_text="$(cat docs/stories/backlog.md)"
root_readme_text="$(cat README.md)"
api_readme_text="$(cat services/api-gateway/README.md)"
main_text="$(cat services/api-gateway/main.go)"
completion_text="$(cat services/api-gateway/internal/processing/completion.go)"
completion_test_text="$(cat services/api-gateway/internal/processing/completion_test.go)"

grep -q 'US-049 Live Processed Product Catalog Smoke' <<<"$story_text"
grep -q 'GET /catalog/products/{id}/model?tier=low|high' <<<"$story_text"
grep -q 'does not add authentication' <<<"$story_text"
grep -q 'WithEventPublisher(eventPublisher)' <<<"$main_text"
grep -q 'NewProductUpdatedEvent(event.ID+"-product-updated"' <<<"$completion_text"
grep -q 'TestHandleTaskCompletedPublishesProductUpdated' <<<"$completion_test_text"
grep -q 'live processed product catalog smoke' <<<"$admin_text"
grep -q 'US-049' <<<"$mobile_text"
grep -q 'US-049' <<<"$platform_text"
grep -q 'US-049 Live Processed Product Catalog Smoke' <<<"$roadmap_text"
grep -q 'US-049 implemented' <<<"$backlog_text"
grep -q 'bash scripts/verify-us-049.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-049.sh' <<<"$api_readme_text"

if grep -Eqi 'checkout|payment|order fulfillment|signed.?url|DELETE /admin/products|POST /cart|/login|JWT|session|authenticate' \
  services/api-gateway/main.go services/api-gateway/internal/processing/*.go services/api-gateway/internal/search/*.go; then
  echo "US-049 must not add checkout, payment, order fulfillment, signed URL, delete, login/session, or cart behavior" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test \
  //services/api-gateway:api_gateway_test \
  //services/api-gateway/internal/product:product_test \
  //services/api-gateway/internal/processing:processing_test \
  //services/api-gateway/internal/search:search_test
bazelisk build \
  //services/api-gateway:api-gateway \
  //infra/k8s:dev-manifests \
  //infra/scripts:dev-cluster \
  //infra/scripts:import-api-image \
  //infra/scripts:import-worker-image
cargo test -p worker-3d
bazelisk test //services/worker-3d/...

verify_cluster="lumin-catalog-live-verify-$$"
context="k3d-${verify_cluster}"
nats_ready_pod="catalog-live-nats-ready"
busybox_image="docker.io/library/busybox:1.36.1"
cluster_images=(
  "docker.io/library/postgres:17.5-alpine"
  "docker.io/minio/minio:RELEASE.2024-08-03T04-33-23Z"
  "docker.io/library/nats:2.11.6-alpine"
  "docker.io/getmeili/meilisearch:v1.46.0"
  "$busybox_image"
)
api_port=$((19080 + ($$ % 1000)))
port_forward_pid=""
port_forward_log=""
product_draft=""
catalog_response=""
search_response=""
category_response=""
category_products_response=""
detail_low_response=""
detail_high_response=""
sprite_file=""
model_low_file=""
model_high_file=""

cleanup() {
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
  fi
  for file in "$port_forward_log" "$product_draft" "$catalog_response" "$search_response" \
    "$category_response" "$category_products_response" "$detail_low_response" \
    "$detail_high_response" "$sprite_file" "$model_low_file" "$model_high_file"; do
    if [[ -n "$file" ]]; then
      rm -f "$file"
    fi
  done
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

import_image_to_k3d_node() {
  local image="$1"
  local node="k3d-${verify_cluster}-server-0"
  docker save --platform linux/arm64 "$image" \
    | docker exec -i "$node" ctr -n k8s.io images import -
}

wait_for_product_item() {
  local url="$1"
  local output_file="$2"
  local product_id="$3"
  local jq_filter="$4"
  for _ in $(seq 1 90); do
    if curl -fsS "$url" >"$output_file" && jq -e --arg id "$product_id" "$jq_filter" "$output_file" >/dev/null; then
      return 0
    fi
    sleep 2
  done
  cat "$output_file" >&2 || true
  return 1
}

for image in "${cluster_images[@]}"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image"
done

LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh create
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/import-api-image.sh
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/import-worker-image.sh
for image in "${cluster_images[@]}"; do
  import_image_to_k3d_node "$image"
done
LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh apply

kubectl --context "$context" -n dev rollout status statefulset/postgres --timeout=300s
kubectl --context "$context" -n dev rollout status statefulset/minio --timeout=300s
kubectl --context "$context" -n dev rollout status deployment/nats --timeout=300s
kubectl --context "$context" -n dev rollout status statefulset/meilisearch --timeout=300s
kubectl --context "$context" -n dev wait --for=condition=complete job/minio-buckets --timeout=300s
kubectl --context "$context" -n dev run "$nats_ready_pod" \
  --image="$busybox_image" \
  --restart=Never \
  --command -- sh -c '
    set -eu
    for _ in $(seq 1 60); do
      if { printf "PING\r\n"; sleep 1; } | nc -w 2 nats 4222 | grep -q PONG; then
        exit 0
      fi
      sleep 2
    done
    exit 1
  '
kubectl --context "$context" -n dev wait "pod/${nats_ready_pod}" \
  --for=jsonpath='{.status.phase}'=Succeeded --timeout=180s

postgres_pod="postgres-0"
kubectl --context "$context" -n dev exec -i "$postgres_pod" -- sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' \
  < <(cat services/api-gateway/migrations/*.sql)
schema_check="$(kubectl --context "$context" -n dev exec "$postgres_pod" -- sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT to_regclass('\''public.products'\''), EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = '\''products'\'' AND column_name = '\''price'\''), EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = '\''products'\'' AND column_name = '\''categories'\'')"')"
grep -q 'products' <<<"$schema_check"
grep -q 't' <<<"$schema_check"

kubectl --context "$context" -n dev rollout status deployment/api-gateway --timeout=300s
kubectl --context "$context" -n dev rollout status deployment/worker-3d --timeout=300s
test "$(kubectl --context "$context" -n dev get deployment worker-3d -o jsonpath='{.status.readyReplicas}')" = "1"

port_forward_log="$(mktemp)"
kubectl --context "$context" -n dev port-forward svc/api-gateway "${api_port}:8080" \
  >"$port_forward_log" 2>&1 &
port_forward_pid="$!"
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${api_port}/readyz" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! curl -fsS "http://127.0.0.1:${api_port}/readyz" >/dev/null 2>&1; then
  cat "$port_forward_log" >&2 || true
  echo "api-gateway port-forward did not become ready" >&2
  exit 1
fi

product_draft="$(mktemp)"
cat >"$product_draft" <<'JSON'
{
  "name": "Arc Chair Live Smoke",
  "slug": "arc-chair-live-smoke",
  "description": "Configurable chair with one source model for live catalog smoke.",
  "price": {
    "amountCents": 12900,
    "currency": "USD",
    "compareAtAmountCents": 15900
  },
  "categories": [
    {
      "slug": "chairs",
      "name": "Chairs"
    }
  ],
  "informationSections": [
    {
      "title": "Materials",
      "body": "Powder coated steel.",
      "collapsedByDefault": true
    }
  ],
  "meshColorConfig": {
    "mesh_body": {
      "default": "#FFFFFF",
      "allowed": ["#FFFFFF", "#000000"]
    }
  }
}
JSON

source_magic="$(od -An -tx1 -N4 resources/pet_tag.glb | tr -d ' \n')"
if [[ "$source_magic" != "676c5446" ]]; then
  echo "source GLB magic check failed for local fixture: got ${source_magic}" >&2
  exit 1
fi

if ! create_response="$(curl -fsS -X POST \
  -H 'Content-Type: application/json' \
  --data @"$product_draft" \
  "http://127.0.0.1:${api_port}/admin/products")"; then
  kubectl --context "$context" -n dev logs deployment/api-gateway --tail=200 >&2 || true
  echo "product create request failed" >&2
  exit 1
fi
product_id="$(jq -r '.id' <<<"$create_response")"
test "$product_id" != "null"
test "$(jq -r '.price.amountCents' <<<"$create_response")" = "12900"
test "$(jq -r '.categories[0].slug' <<<"$create_response")" = "chairs"
test "$(jq -r '.processingStatus' <<<"$create_response")" = "not_started"

if ! upload_response="$(curl -fsS -X POST \
  -F 'source=@resources/pet_tag.glb;filename=source.glb;type=model/gltf-binary' \
  "http://127.0.0.1:${api_port}/admin/products/${product_id}/source-glb")"; then
  kubectl --context "$context" -n dev logs deployment/api-gateway --tail=200 >&2 || true
  kubectl --context "$context" -n dev logs deployment/worker-3d --tail=200 >&2 || true
  echo "source upload request failed" >&2
  exit 1
fi
test "$(jq -r '.processingStatus' <<<"$upload_response")" = "queued"

status=""
record=""
for _ in $(seq 1 120); do
  record="$(curl -fsS "http://127.0.0.1:${api_port}/admin/products/${product_id}")"
  status="$(jq -r '.processingStatus' <<<"$record")"
  if [[ "$status" = "completed" || "$status" = "failed" ]]; then
    break
  fi
  sleep 5
done
if [[ "$status" != "completed" ]]; then
  kubectl --context "$context" -n dev logs deployment/worker-3d --tail=200 >&2 || true
  kubectl --context "$context" -n dev logs deployment/api-gateway --tail=200 >&2 || true
  echo "product ${product_id} did not complete; final status: ${status}" >&2
  exit 1
fi
test "$(jq -r '.optimizedAsset.bucket' <<<"$record")" = "lumin-optimized-glb"
test "$(jq -r '.spriteAsset.bucket' <<<"$record")" = "lumin-360-sprites"

catalog_response="$(mktemp)"
search_response="$(mktemp)"
category_response="$(mktemp)"
category_products_response="$(mktemp)"
detail_low_response="$(mktemp)"
detail_high_response="$(mktemp)"
sprite_file="$(mktemp)"
model_low_file="$(mktemp)"
model_high_file="$(mktemp)"

item_filter='.items[] | select(.id == $id and .processingStatus == "completed" and .price.amountCents == 12900 and .categories[0].slug == "chairs" and .spriteAsset.bucket == "lumin-360-sprites")'
wait_for_product_item "http://127.0.0.1:${api_port}/catalog/products?limit=20" "$catalog_response" "$product_id" "$item_filter"
wait_for_product_item "http://127.0.0.1:${api_port}/catalog/search?q=Arc&limit=20" "$search_response" "$product_id" "$item_filter"
wait_for_product_item "http://127.0.0.1:${api_port}/catalog/categories/chairs/products?sort=price_asc&limit=20" "$category_products_response" "$product_id" "$item_filter"

for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${api_port}/catalog/categories" >"$category_response" \
    && jq -e '.categories[] | select(.slug == "chairs" and .name == "Chairs")' "$category_response" >/dev/null; then
    break
  fi
  sleep 2
done
jq -e '.categories[] | select(.slug == "chairs" and .name == "Chairs")' "$category_response" >/dev/null

curl -fsS "http://127.0.0.1:${api_port}/catalog/products/${product_id}?tier=low" >"$detail_low_response"
jq -e --arg id "$product_id" '.id == $id and .modelTier == "low" and .processingStatus == "completed" and .modelAsset.bucket == "lumin-optimized-glb" and .spriteAsset.bucket == "lumin-360-sprites" and .spriteUrl == ("/catalog/products/" + $id + "/sprite")' "$detail_low_response" >/dev/null
curl -fsS "http://127.0.0.1:${api_port}/catalog/products/${product_id}?tier=high" >"$detail_high_response"
jq -e --arg id "$product_id" '.id == $id and .modelTier == "high" and .modelAsset.bucket == "lumin-source-glb" and .modelUrl == ("/catalog/products/" + $id + "/model?tier=high")' "$detail_high_response" >/dev/null

curl -fsS "http://127.0.0.1:${api_port}/catalog/products/${product_id}/sprite" >"$sprite_file"
sprite_magic="$(od -An -tx1 -N2 "$sprite_file" | tr -d ' \n')"
test "$sprite_magic" = "ffd8"

curl -fsS "http://127.0.0.1:${api_port}/catalog/products/${product_id}/model?tier=low" >"$model_low_file"
low_magic="$(od -An -tx1 -N4 "$model_low_file" | tr -d ' \n')"
test "$low_magic" = "676c5446"

curl -fsS "http://127.0.0.1:${api_port}/catalog/products/${product_id}/model?tier=high" >"$model_high_file"
high_magic="$(od -An -tx1 -N4 "$model_high_file" | tr -d ' \n')"
test "$high_magic" = "676c5446"

echo "US-049 verification passed for ${product_id}"
