#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-022" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-022.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-022-admin-source-glb-upload-and-task-event.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
readme_text="$(cat services/api-gateway/README.md)"
root_readme_text="$(cat README.md)"
main_text="$(cat services/api-gateway/main.go)"
handler_text="$(cat services/api-gateway/internal/product/handler.go)"
events_text="$(cat services/api-gateway/internal/product/events.go)"
source_assets_text="$(cat services/api-gateway/internal/product/source_assets.go)"
store_text="$(cat services/api-gateway/internal/product/store.go)"
handler_test_text="$(cat services/api-gateway/internal/product/handler_test.go)"
store_test_text="$(cat services/api-gateway/internal/product/store_test.go)"
main_test_text="$(cat services/api-gateway/main_test.go)"
product_build_text="$(cat services/api-gateway/internal/product/BUILD.bazel)"
api_build_text="$(cat services/api-gateway/BUILD.bazel)"

grep -q 'US-022 Admin Source GLB Upload And Task Event' <<<"$story_text"
grep -q 'POST /admin/products/{id}/source-glb' <<<"$story_text"
grep -q '3d.task.created' <<<"$story_text"
grep -q 'This story does not add admin UI behavior' <<<"$story_text"
grep -q 'retry/outbox semantics' <<<"$story_text"

for required in \
  'administrator source GLB upload' \
  'POST /admin/products/{id}/source-glb' \
  'lumin-source-glb/products/{productId}/source.glb' \
  '`queued` processing status' \
  '`3d.task.created`' \
  'worker mesh'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-022 Admin Source GLB Upload And Task Event' <<<"$roadmap_text"
grep -q 'US-022' <<<"$platform_text"
grep -q 'bash scripts/verify-us-022.sh' <<<"$readme_text"
grep -q 'bash scripts/verify-us-022.sh' <<<"$root_readme_text"

for required in \
  'WithSourceAssetStore(product.NewMinIOSourceAssetStore(checker.MinIO()))' \
  'POST /admin/products/{id}/source-glb'; do
  grep -q "$required" <<<"$main_text"
done

for required in \
  'type SourceAssetStore interface' \
  'func (handler Handler) UploadProductSource' \
  'request.ParseMultipartForm' \
  'request.FormFile("source")' \
  'strings.HasSuffix(strings.ToLower(header.Filename), ".glb")' \
  'handler.sourceAssets.PutSourceAsset' \
  'handler.repository.QueueSourceAsset' \
  'handler.publishProductUpdated' \
  'handler.publishProcessingTaskCreated' \
  'func NewTaskID'; do
  grep -q "$required" <<<"$handler_text"
done

for required in \
  'type TaskCreatedEvent struct' \
  'type TaskCreatedPayload struct' \
  'func NewTaskCreatedEvent' \
  '"3d.task.created"' \
  'ProcessingTaskCreatedSubject' \
  'PublishProcessingTaskCreated' \
  'lumin.3d.task.created'; do
  grep -q "$required" <<<"$events_text"
done

for required in \
  'type MinIOSourceAssetStore struct' \
  'func NewMinIOSourceAssetStore' \
  'func (store MinIOSourceAssetStore) PutSourceAsset' \
  'sourceGLBBucket' \
  'sourceGLBContentType' \
  'client.PutObject' \
  'products/%s/source.glb'; do
  grep -q "$required" <<<"$source_assets_text"
done

for required in \
  'queueSourceAssetSQL' \
  'processing_status = $3' \
  'ProcessingQueued' \
  'func NewQueueSourceAssetArgs' \
  'func (store Store) QueueSourceAsset'; do
  grep -q "$required" <<<"$store_text"
done

for required in \
  'TestUploadProductSourceStoresAssetQueuesRecordAndPublishesTask' \
  'TestUploadProductSourceRequiresMeshColorConfig' \
  'TestUploadProductSourceRejectsNonGLBFilename' \
  'TestNewTaskIDMatchesProcessingTaskContract' \
  'TestNewTaskCreatedEventMatchesContract'; do
  grep -q "$required" <<<"$handler_test_text"
done

grep -q 'TestNewQueueSourceAssetArgsEncodesQueuedSourceAsset' <<<"$store_test_text"
grep -q 'TestRoutesExposeAdminProductSourceUpload' <<<"$main_test_text"
grep -q '@com_github_minio_minio_go_v7//:minio-go' <<<"$product_build_text"
grep -q '//services/api-gateway/internal/product' <<<"$api_build_text"

if grep -Eqi 'meshoptimizer|VisibilityDetector|flutter|BLoC|payment|checkout|event_outbox|CREATE TABLE.*outbox|GET /search|GET /catalog|3d.task.completed' \
  services/api-gateway/main.go services/api-gateway/internal/product/*.go services/api-gateway/migrations/*.sql; then
  echo "US-022 must not add worker processing, UI, checkout, outbox, customer search routes, or task completion consumption" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway:api_gateway_test //services/api-gateway/internal/product:product_test //services/api-gateway/internal/search:search_test
bazelisk build //services/api-gateway:api-gateway

echo "US-022 verification passed"
