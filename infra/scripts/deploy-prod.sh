#!/usr/bin/env bash
# Deploy lumin-studio lên cluster k3d self-hosted (mặc định: luminstudio trên máy WSL2).
#
# Luồng: build ảnh amd64 ngay trên host -> k3d image import -> kubectl apply -k overlays/prod
# -> rollout. Không cần registry. Idempotent: chạy lại nhiều lần an toàn.
#
# Biến môi trường:
#   LUMIN_CLUSTER_NAME  tên cluster k3d (mặc định: luminstudio)
#   IMAGE_TAG           tag ảnh (mặc định: prod). Đặt = git sha để deploy bất biến + rollback.
#   SKIP_BUILD=1        bỏ qua build/import, chỉ apply lại manifest.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cluster_name="${LUMIN_CLUSTER_NAME:-luminstudio}"
cluster_context="k3d-${cluster_name}"
image_tag="${IMAGE_TAG:-prod}"
prod_overlay="$repo_root/infra/k8s/overlays/prod"
secrets_dir="$prod_overlay/secrets"
# Nguồn sự thật của secrets nằm NGOÀI checkout: runner CI dùng workspace riêng
# (~/actions-runner/_work/...) nên file secrets/*.env trong overlay không tồn tại ở đó.
# Lưu cố định tại đây để mọi lần deploy (CI hay tay) tái dùng cùng một secret, tránh
# sinh mật khẩu mới lệch với data Postgres/MinIO đã khởi tạo.
persist_dir="${LUMIN_SECRETS_DIR:-$HOME/.config/lumin/prod-secrets}"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror: %s\033[0m\n' "$*" >&2; exit 1; }

for cmd in docker k3d kubectl openssl; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd là bắt buộc"
done

# Bazel cần để build ảnh API; ưu tiên bazelisk.
bazel_bin=""
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  if command -v bazelisk >/dev/null 2>&1; then bazel_bin="bazelisk"
  elif command -v bazel >/dev/null 2>&1; then bazel_bin="bazel"
  else die "cần bazelisk (hoặc bazel) để build ảnh api-gateway; xem docs/deploy-self-hosted.md"; fi
fi

# kubeconfig: SSH non-interactive không tự set KUBECONFIG, nên ta ghi tường minh.
export KUBECONFIG="$(k3d kubeconfig write "$cluster_name")"

k3d cluster list --no-headers | awk -v n="$cluster_name" '$1==n{f=1} END{exit !f}' \
  || die "cluster k3d '$cluster_name' không tồn tại"

# ---------------------------------------------------------------------------
# 1. Secrets prod: nguồn sự thật ở persist_dir; sinh ngẫu nhiên lần đầu rồi copy
#    vào overlay để kustomize đọc. Cả hai vị trí đều gitignore / ngoài repo.
# ---------------------------------------------------------------------------
ensure_secret() {
  local name="$1"; shift
  local persist="$persist_dir/$name"
  if [ ! -f "$persist" ]; then
    log "Sinh secret prod mới: $name (lưu tại $persist_dir)"
    printf '%s\n' "$@" > "$persist"
    chmod 600 "$persist"
  fi
  cp "$persist" "$secrets_dir/$name"
  chmod 600 "$secrets_dir/$name"
}
mkdir -p "$secrets_dir" "$persist_dir"
ensure_secret "postgres.env" \
  "POSTGRES_DB=lumin" "POSTGRES_USER=lumin" "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
ensure_secret "minio.env" \
  "MINIO_ROOT_USER=lumin-prod" "MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)"
ensure_secret "meilisearch.env" \
  "MEILI_MASTER_KEY=$(openssl rand -hex 32)"

# ---------------------------------------------------------------------------
# 2. Build + import ảnh (amd64) vào cluster.
# ---------------------------------------------------------------------------
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  log "Build api-gateway (amd64) bằng $bazel_bin"
  ( cd "$repo_root" && "$bazel_bin" run //services/api-gateway:api-gateway-image-load-amd64 )
  docker tag lumin/api-gateway:dev "lumin/api-gateway:$image_tag"

  log "Build worker-3d"
  ( cd "$repo_root" && docker build -f services/worker-3d/Dockerfile -t "lumin/worker-3d:$image_tag" . )

  log "Import ảnh vào cluster $cluster_name (tag=$image_tag)"
  k3d image import "lumin/api-gateway:$image_tag" "lumin/worker-3d:$image_tag" --cluster "$cluster_name"
fi

# ---------------------------------------------------------------------------
# 3. Áp dụng overlay prod.
# ---------------------------------------------------------------------------
log "Bảo đảm namespace prod tồn tại"
kubectl --context "$cluster_context" create namespace prod \
  --dry-run=client -o yaml | kubectl --context "$cluster_context" apply -f -

# ConfigMap chứa các file migration .sql. Tạo imperative từ nguồn duy nhất
# (services/api-gateway/migrations) vì kustomize không đọc được file ngoài thư mục overlay.
log "Cập nhật ConfigMap db-migrations từ services/api-gateway/migrations"
cm_args=()
for f in "$repo_root"/services/api-gateway/migrations/*.sql; do cm_args+=(--from-file="$f"); done
kubectl --context "$cluster_context" -n prod create configmap db-migrations "${cm_args[@]}" \
  --dry-run=client -o yaml | kubectl --context "$cluster_context" apply -f -

# db-migrate và minio-buckets là Job: pod template bất biến nên `apply` lỗi
# "field is immutable" mỗi khi nội dung đổi. Xoá trước để apply tạo lại. Cả hai
# đều idempotent (schema_migrations / `mc mb --ignore-existing`) nên không mất dữ liệu.
kubectl --context "$cluster_context" -n prod delete job db-migrate minio-buckets --ignore-not-found

log "kubectl apply -k overlays/prod"
kubectl --context "$cluster_context" apply -k "$prod_overlay"

log "Chờ migration schema hoàn tất"
kubectl --context "$cluster_context" -n prod wait --for=condition=complete job/db-migrate --timeout=180s

# ---------------------------------------------------------------------------
# 4. Lăn bản mới.
# ---------------------------------------------------------------------------
if [ "$image_tag" = "prod" ]; then
  # Tag không đổi -> ép tạo pod mới để dùng ảnh vừa import.
  kubectl --context "$cluster_context" -n prod rollout restart deploy/api-gateway deploy/worker-3d
else
  kubectl --context "$cluster_context" -n prod set image deploy/api-gateway "api-gateway=lumin/api-gateway:$image_tag"
  kubectl --context "$cluster_context" -n prod set image deploy/worker-3d "worker-3d=lumin/worker-3d:$image_tag"
fi

log "Chờ rollout hoàn tất"
kubectl --context "$cluster_context" -n prod rollout status deploy/api-gateway --timeout=180s
kubectl --context "$cluster_context" -n prod rollout status deploy/worker-3d --timeout=300s

log "Xong. Trạng thái namespace prod:"
kubectl --context "$cluster_context" -n prod get deploy,pods,ingress
