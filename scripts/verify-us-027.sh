#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-027" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-027.sh

story_text="$(cat docs/stories/epics/E07-3d-processing/US-027-api-processing-completion-consumption.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
completion_text="$(cat services/api-gateway/internal/processing/completion.go)"
store_text="$(cat services/api-gateway/internal/product/store.go)"
events_text="$(cat services/api-gateway/internal/product/events.go)"
main_text="$(cat services/api-gateway/main.go)"

grep -q 'US-027 API Processing Completion Consumption' <<<"$story_text"
grep -q 'ProcessingTaskCompletedSubject = "lumin.3d.task.completed"' <<<"$events_text"
grep -q 'HandleTaskCompleted' <<<"$completion_text"
grep -q 'decoder.DisallowUnknownFields()' <<<"$completion_text"
grep -q 'CompleteProcessing' <<<"$completion_text"
grep -q 'const completeProcessingSQL' <<<"$store_text"
grep -q 'processing_status = $4' <<<"$store_text"
grep -q 'updated_at <= $5' <<<"$store_text"
grep -q 'processing.NewNATSSubscriber' <<<"$main_text"
grep -q 'consumes valid v1 `3d.task.completed` events' <<<"$admin_text"

if grep -Eqi 'worker image|Deployment|StatefulSet|dead.?letter|event_outbox|GET /catalog|GET /search|flutter|payment|checkout' \
  services/api-gateway/internal/processing/completion.go; then
  echo "US-027 must not add worker deployment, outbox/dead-letter, catalog, mobile, or checkout behavior" >&2
  exit 1
fi

(
  cd services/api-gateway
  gofmt -w main.go internal/product/events.go internal/product/store.go internal/product/store_test.go \
    internal/processing/completion.go internal/processing/completion_test.go
  go test ./...
)
bazelisk test //services/api-gateway:api_gateway_test \
  //services/api-gateway/internal/product:product_test \
  //services/api-gateway/internal/search:search_test \
  //services/api-gateway/internal/processing:processing_test
bazelisk build //services/api-gateway:api-gateway

echo "US-027 verification passed"
