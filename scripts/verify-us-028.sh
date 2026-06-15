#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk cargo curl docker jq k3d kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-028" >&2
    exit 1
  fi
done

docker info >/dev/null
bash -n \
  infra/scripts/dev-cluster.sh \
  infra/scripts/import-api-image.sh \
  infra/scripts/import-worker-image.sh \
  scripts/verify-us-028.sh

story_text="$(cat docs/stories/epics/E07-3d-processing/US-028-worker-k3d-deployment-and-live-processing-smoke.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
worker_readme="$(cat services/worker-3d/README.md)"
worker_manifest="$(cat infra/k8s/base/worker-3d-deployment.yaml)"
worker_main="$(cat services/worker-3d/src/main.rs)"
worker_runtime="$(cat services/worker-3d/src/runtime.rs)"
worker_dockerfile="$(cat services/worker-3d/Dockerfile)"
import_script="$(cat infra/scripts/import-worker-image.sh)"

grep -q 'US-028 Worker K3d Deployment And Live Processing Smoke' <<<"$story_text"
grep -q 'WORKER_RUNTIME' <<<"$worker_manifest"
grep -q 'image: lumin/worker-3d:dev' <<<"$worker_manifest"
grep -q 'NATS_HOST' <<<"$worker_manifest"
grep -q 'MINIO_ENDPOINT' <<<"$worker_manifest"
grep -q 'BLENDER_RENDER_SCRIPT' <<<"$worker_manifest"
grep -q 'readOnlyRootFilesystem: true' <<<"$worker_manifest"
grep -q 'emptyDir: {}' <<<"$worker_manifest"
grep -q 'run_forever_from_env' <<<"$worker_main"
grep -q 'run_forever' <<<"$worker_runtime"
grep -q 'WORKER_RUN_ONCE' <<<"$worker_runtime"
grep -q 'docker build -f services/worker-3d/Dockerfile -t lumin/worker-3d:dev .' <<<"$import_script"
grep -q 'apt-get install -y --no-install-recommends blender ca-certificates libegl1 python3-numpy' <<<"$worker_dockerfile"
grep -q 'worker image' <<<"$admin_text"
grep -q 'US-028' <<<"$platform_text"
grep -q 'K3d' <<<"$worker_readme"

if grep -Eqi 'dead.?letter|event_outbox|GET /catalog|GET /search|VisibilityDetector|flutter|payment|checkout|authorization|auth' \
  services/worker-3d/src/*.rs infra/k8s/base/worker-3d-deployment.yaml; then
  echo "US-028 must not add retry/dead-letter, outbox, catalog, mobile, checkout, auth, or authorization behavior" >&2
  exit 1
fi

cargo fmt --all -- --check
cargo test -p worker-3d
bazelisk test //services/worker-3d/...
bazelisk build \
  //infra/k8s:dev-manifests \
  //infra/scripts:dev-cluster \
  //infra/scripts:import-api-image \
  //infra/scripts:import-worker-image

docker build -f services/worker-3d/Dockerfile -t lumin/worker-3d:dev .
test "$(docker run --rm -e WORKER_RUNTIME=0 -e WORKER_CONCURRENCY=2 lumin/worker-3d:dev | jq -r '.status')" = "ready"
docker run --rm --entrypoint /usr/bin/blender lumin/worker-3d:dev --version | grep -q '^Blender '

verify_cluster="lumin-worker-live-verify-$$"
context="k3d-${verify_cluster}"
nats_ready_pod="worker-live-nats-ready"
busybox_image="docker.io/library/busybox:1.36.1"
cluster_images=(
  "docker.io/library/postgres:17.5-alpine"
  "docker.io/minio/minio:RELEASE.2024-08-03T04-33-23Z"
  "docker.io/library/nats:2.11.6-alpine"
  "docker.io/getmeili/meilisearch:v1.46.0"
  "$busybox_image"
)
port_forward_pid=""
port_forward_log=""
cleanup() {
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$port_forward_log" ]]; then
    rm -f "$port_forward_log"
  fi
  LUMIN_CLUSTER_NAME="$verify_cluster" infra/scripts/dev-cluster.sh delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

import_image_to_k3d_node() {
  local image="$1"
  local node="k3d-${verify_cluster}-server-0"
  docker save --platform linux/arm64 "$image" \
    | docker exec -i "$node" ctr -n k8s.io images import -
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
  < services/api-gateway/migrations/001_create_products.sql
schema_check="$(kubectl --context "$context" -n dev exec "$postgres_pod" -- sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT to_regclass('\''public.products'\'')"')"
grep -q 'products' <<<"$schema_check"

kubectl --context "$context" -n dev rollout status deployment/api-gateway --timeout=300s
kubectl --context "$context" -n dev rollout status deployment/worker-3d --timeout=300s
test "$(kubectl --context "$context" -n dev get deployment worker-3d -o jsonpath='{.status.readyReplicas}')" = "1"

api_port=$((18080 + ($$ % 1000)))
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
cat > "$product_draft" <<'JSON'
{
  "name": "Arc Chair",
  "slug": "arc-chair",
  "description": "Configurable chair with one source model.",
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
source_size="$(wc -c < resources/pet_tag.glb | tr -d ' ')"
if [[ "$(stat -f '%z' resources/pet_tag.glb)" != "$source_size" ]]; then
  echo "source GLB size check failed for local fixture" >&2
  exit 1
fi
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
  kubectl --context "$context" -n dev logs deployment/worker-3d --tail=200 >&2 || true
  kubectl --context "$context" -n dev exec "$postgres_pod" -- sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\d products"' >&2 || true
  echo "product create request failed" >&2
  exit 1
fi
product_id="$(jq -r '.id' <<<"$create_response")"
test "$product_id" != "null"
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
  if [[ "$status" = "completed" ]]; then
    break
  fi
  if [[ "$status" = "failed" ]]; then
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
test "$(jq -r '.optimizedAsset.key' <<<"$record")" = "${product_id}_low.glb"
test "$(jq -r '.spriteAsset.key' <<<"$record")" = "${product_id}_360_sprite.jpg"

echo "US-028 verification passed for ${product_id}"
