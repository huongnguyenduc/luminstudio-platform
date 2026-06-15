#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-018" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-018.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-018-admin-product-read-http-api.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
readme_text="$(cat services/api-gateway/README.md)"
main_text="$(cat services/api-gateway/main.go)"
handler_text="$(cat services/api-gateway/internal/product/handler.go)"
handler_test_text="$(cat services/api-gateway/internal/product/handler_test.go)"
main_test_text="$(cat services/api-gateway/main_test.go)"
store_text="$(cat services/api-gateway/internal/product/store.go)"

grep -q 'US-018 Admin Product Read HTTP API' <<<"$story_text"
grep -q 'GET /admin/products' <<<"$story_text"
grep -q 'GET /admin/products/{id}' <<<"$story_text"
grep -q 'This story does not add admin UI behavior, product update/delete workflows' <<<"$story_text"

for required in \
  'GET /admin/products' \
  'GET /admin/products/{id}' \
  'use PostgreSQL as the source of truth' \
  'Authentication, authorization' \
  'event publication, search synchronization, and worker processing'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-018 Admin Product Read HTTP API' <<<"$roadmap_text"
grep -q 'GET /admin/products' <<<"$readme_text"

for required in \
  'mux.HandleFunc("GET /admin/products", productHandler.ListProducts)' \
  'mux.HandleFunc("GET /admin/products/{id}", productHandler.GetProduct)' \
  'product.NewHandler(product.NewStore(checker.Postgres()))'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'func (handler Handler) GetProduct' \
  'func (handler Handler) ListProducts' \
  'productIDPattern.MatchString(id)' \
  'errors.Is(err, ErrProductNotFound)' \
  'http.StatusNotFound' \
  'writeJSON(response, http.StatusOK, records)'; do
  grep -q "$required" <<<"$handler_text"
done

for required in \
  'func (store Store) GetProduct' \
  'func (store Store) ListProducts' \
  'const getProductSQL' \
  'const listProductsSQL' \
  'ORDER BY updated_at DESC, id ASC' \
  'var ErrProductNotFound'; do
  grep -q "$required" <<<"$store_text"
done

for required in \
  'TestGetProductReturnsRecord' \
  'TestGetProductRejectsInvalidID' \
  'TestGetProductReturnsNotFound' \
  'TestListProductsReturnsRecords'; do
  grep -q "$required" <<<"$handler_test_text"
done

for required in \
  'TestRoutesExposeAdminProductList' \
  'TestRoutesExposeAdminProductGet'; do
  grep -q "$required" <<<"$main_test_text"
done

if grep -Eqi 'nats\.Connect|Publish|Subscribe|minio\..*PutObject|meshoptimizer|Meili|VisibilityDetector|flutter|BLoC|payment|checkout' \
  services/api-gateway/main.go services/api-gateway/internal/product/*.go; then
  echo "US-018 must not add runtime NATS, MinIO upload, worker processing, search sync, mobile UI, or checkout behavior" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway:api-gateway

echo "US-018 verification passed"
