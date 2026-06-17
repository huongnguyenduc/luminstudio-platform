#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-017" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-017.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-017-admin-product-http-api.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
readme_text="$(cat services/api-gateway/README.md)"
main_text="$(cat services/api-gateway/main.go)"
handler_text="$(cat services/api-gateway/internal/product/handler.go)"
handler_test_text="$(cat services/api-gateway/internal/product/handler_test.go)"

grep -q 'US-017 Admin Product HTTP API' <<<"$story_text"
grep -q 'POST /admin/products' <<<"$story_text"
grep -q 'This story does not add admin UI behavior, MinIO uploads, NATS' <<<"$story_text"

for required in \
  'POST /admin/products' \
  'validates the draft at the HTTP boundary' \
  'Authentication, authorization' \
  'event publication, search synchronization, and worker processing'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-017 Admin Product HTTP API' <<<"$roadmap_text"
grep -q 'POST /admin/products' <<<"$readme_text"

for required in \
  'mux.HandleFunc("POST /admin/products", productHandler.CreateProduct)' \
  'product.NewHandler(product.NewStore(checker.Postgres()))'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'func (handler Handler) CreateProduct' \
  'decoder.DisallowUnknownFields()' \
  'draft.Validate()' \
  'handler.creator.InsertProduct' \
  'func NewID()' \
  'http.StatusCreated'; do
  grep -q "$required" <<<"$handler_text"
done

for required in \
  'TestCreateProductPersistsValidatedDraft' \
  'TestCreateProductRejectsInvalidDraft' \
  'TestCreateProductRejectsTrailingJSON' \
  'TestCreateProductReportsPersistenceFailure' \
  'TestNewIDMatchesProductContract'; do
  grep -q "$required" <<<"$handler_test_text"
done

if grep -Eqi 'nats\.Connect|Publish|Subscribe|minio\..*PutObject|meshoptimizer|Meili|VisibilityDetector|flutter|BLoC|payment|checkout' \
  services/api-gateway/main.go services/api-gateway/internal/product/*.go; then
  echo "US-017 must not add runtime NATS, MinIO upload, worker processing, search sync, mobile UI, or checkout behavior" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway:api-gateway

echo "US-017 verification passed"
