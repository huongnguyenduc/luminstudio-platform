#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-020" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-020.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-020-admin-product-mutation-event-publication.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
readme_text="$(cat services/api-gateway/README.md)"
main_text="$(cat services/api-gateway/main.go)"
handler_text="$(cat services/api-gateway/internal/product/handler.go)"
events_text="$(cat services/api-gateway/internal/product/events.go)"
handler_test_text="$(cat services/api-gateway/internal/product/handler_test.go)"
build_text="$(cat services/api-gateway/internal/product/BUILD.bazel)"
event_schema_text="$(cat packages/shared-types/contracts/v1/events.schema.json)"

grep -q 'US-020 Admin Product Mutation Event Publication' <<<"$story_text"
grep -q 'product.updated' <<<"$story_text"
grep -q 'This story does not add admin UI behavior' <<<"$story_text"
grep -q 'retry/outbox semantics' <<<"$story_text"

for required in \
  'publishes a v1 `product.updated` event' \
  'correlation identity' \
  'retry/outbox semantics' \
  'search synchronization'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-020 Admin Product Mutation Event Publication' <<<"$roadmap_text"
grep -q 'US-020' <<<"$platform_text"
grep -q 'product.updated' <<<"$readme_text"
grep -q 'bash scripts/verify-us-020.sh' <<<"$readme_text"

for required in \
  'WithEventPublisher(product.NewNATSPublisher(config.NATSURL, config.DependencyTimeout))' \
  'mux.HandleFunc("POST /admin/products", productHandler.CreateProduct)' \
  'mux.HandleFunc("PUT /admin/products/{id}", productHandler.UpdateProduct)'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type EventPublisher interface' \
  'type ProductUpdatedEvent struct' \
  'type ProductUpdatedPayload struct' \
  'func NewProductUpdatedEvent' \
  'type NATSPublisher struct' \
  'func NewNATSPublisher' \
  'PublishProductUpdated' \
  'productUpdatedSubject' \
  '"lumin.product.updated"' \
  'correlationIDHeader' \
  '"X-Correlation-ID"' \
  'PING'; do
  grep -q "$required" <<<"$events_text"
done

for required in \
  'eventPublisher EventPublisher' \
  'func (handler Handler) WithEventPublisher' \
  'correlationIDForRequest' \
  'handler.publishProductUpdated(request.Context(), record, correlationID)' \
  'NewEventID' \
  'NewCorrelationID' \
  'http.StatusBadGateway'; do
  grep -q "$required" <<<"$handler_text"
done

for required in \
  'eventPublisherStub' \
  'TestCreateProductPersistsValidatedDraft' \
  'publisher.calls != 1' \
  'corr_request' \
  'TestCreateProductRejectsInvalidCorrelationID' \
  'TestCreateProductReportsEventPublicationFailure' \
  'TestUpdateProductPersistsValidatedDraft' \
  'TestUpdateProductReportsEventPublicationFailure' \
  'TestNewProductUpdatedEventMatchesContract'; do
  grep -q "$required" <<<"$handler_test_text"
done

grep -q '"events.go"' <<<"$build_text"
grep -q '"product.updated"' <<<"$event_schema_text"
grep -q '"ProductUpdatedPayload"' <<<"$event_schema_text"

if grep -Eqi 'Subscribe|Meili|PutObject|meshoptimizer|VisibilityDetector|flutter|BLoC|payment|checkout|event_outbox|CREATE TABLE.*outbox' \
  services/api-gateway/main.go services/api-gateway/internal/product/*.go services/api-gateway/migrations/*.sql; then
  echo "US-020 must not add search sync, MinIO upload, worker processing, UI, checkout, or outbox behavior" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway:api-gateway

echo "US-020 verification passed"
