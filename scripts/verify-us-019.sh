#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-019" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-019.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-019-admin-product-update-http-api.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
readme_text="$(cat services/api-gateway/README.md)"
main_text="$(cat services/api-gateway/main.go)"
handler_text="$(cat services/api-gateway/internal/product/handler.go)"
handler_test_text="$(cat services/api-gateway/internal/product/handler_test.go)"
main_test_text="$(cat services/api-gateway/main_test.go)"
store_text="$(cat services/api-gateway/internal/product/store.go)"
store_test_text="$(cat services/api-gateway/internal/product/store_test.go)"

grep -q 'US-019 Admin Product Update HTTP API' <<<"$story_text"
grep -q 'PUT /admin/products/{id}' <<<"$story_text"
grep -q 'full-replacement' <<<"$story_text"
grep -q 'This story does not add admin UI behavior, product delete workflows, partial' <<<"$story_text"

for required in \
  'PUT /admin/products/{id}' \
  'full-replacement product updates' \
  'preserves server-owned identity' \
  'Authentication, authorization' \
  'event publication, search synchronization, and worker processing'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-019 Admin Product Update HTTP API' <<<"$roadmap_text"
grep -q 'PUT /admin/products/{id}' <<<"$readme_text"

for required in \
  'mux.HandleFunc("PUT /admin/products/{id}", productHandler.UpdateProduct)' \
  'product.NewHandler(product.NewStore(checker.Postgres()))'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type Updater interface' \
  'UpdateProduct(ctx context.Context, id string, draft ProductDraft, now time.Time)' \
  'func (handler Handler) UpdateProduct' \
  'productIDPattern.MatchString(id)' \
  'errors.Is(err, ErrProductNotFound)' \
  'http.StatusNotFound' \
  'writeJSON(response, http.StatusOK, record)'; do
  grep -q "$required" <<<"$handler_text"
done

for required in \
  'const updateProductSQL' \
  'UPDATE products' \
  'WHERE id = $1' \
  'RETURNING id, slug, name, description' \
  'func NewUpdateProductArgs' \
  'func (store Store) UpdateProduct' \
  'errors.Is(err, pgx.ErrNoRows)' \
  'ErrProductNotFound'; do
  grep -q "$required" <<<"$store_text"
done

for required in \
  'TestUpdateProductPersistsValidatedDraft' \
  'TestUpdateProductRejectsInvalidID' \
  'TestUpdateProductRejectsInvalidDraft' \
  'TestUpdateProductRejectsTrailingJSON' \
  'TestUpdateProductReturnsNotFound'; do
  grep -q "$required" <<<"$handler_test_text"
done

for required in \
  'TestNewUpdateProductArgsEncodesValidatedDraft' \
  'TestNewUpdateProductArgsRejectsInvalidInput'; do
  grep -q "$required" <<<"$store_test_text"
done

grep -q 'TestRoutesExposeAdminProductUpdate' <<<"$main_test_text"

if grep -Eqi 'nats\.Connect|Publish|Subscribe|minio\..*PutObject|meshoptimizer|Meili|VisibilityDetector|flutter|BLoC|payment|checkout' \
  services/api-gateway/main.go services/api-gateway/internal/product/*.go; then
  echo "US-019 must not add runtime NATS, MinIO upload, worker processing, search sync, mobile UI, or checkout behavior" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway:api-gateway

echo "US-019 verification passed"
