#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk cargo grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-026" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-026.sh

story_text="$(cat docs/stories/epics/E07-3d-processing/US-026-worker-runtime-processing-and-output-upload.md)"
decision_text="$(cat docs/decisions/0013-use-official-minio-rust-sdk.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
pipeline_text="$(cat services/worker-3d/src/processing_pipeline.rs)"
runtime_text="$(cat services/worker-3d/src/runtime.rs)"
main_text="$(cat services/worker-3d/src/main.rs)"
cargo_text="$(cat services/worker-3d/Cargo.toml)"
notices_text="$(cat docs/THIRD_PARTY_NOTICES.md)"

grep -q 'US-026 Worker Runtime Processing And Output Upload' <<<"$story_text"
grep -q 'Use The Official MinIO Rust SDK' <<<"$decision_text"
grep -q 'minio = { version = "=0.4.0"' <<<"$cargo_text"
grep -q 'minio 0.4.0' <<<"$notices_text"
grep -q 'pub const TASK_COMPLETED_SUBJECT: &str = "lumin.3d.task.completed"' <<<"$pipeline_text"
grep -q 'pub struct ProcessingPipeline' <<<"$pipeline_text"
grep -q 'put_processed_asset' <<<"$pipeline_text"
grep -q 'publish_task_completed' <<<"$pipeline_text"
grep -q 'impl SourceAssetReader for MinioAssetStore' <<<"$runtime_text"
grep -q 'impl ProcessedAssetStore for MinioAssetStore' <<<"$runtime_text"
grep -q 'impl SpriteRenderer for BlenderSpriteRenderer' <<<"$runtime_text"
grep -q '"--disable-autoexec"' <<<"$runtime_text"
grep -q '"--python-exit-code"' <<<"$runtime_text"
grep -q 'impl CompletionPublisher for NATSTaskCompletedPublisher' <<<"$runtime_text"
grep -q 'run_once_from_env' <<<"$main_text"
grep -q 'uploads processed assets to MinIO' <<<"$admin_text"
grep -q 'publishes a v1 `3d.task.completed` event' <<<"$admin_text"

node <<'NODE'
const fs = require('fs');
const schema = JSON.parse(fs.readFileSync('packages/shared-types/contracts/v1/events.schema.json'));
const payload = schema.$defs.TaskCompletedPayload;
for (const field of ['taskId', 'productId', 'optimizedAsset', 'spriteAsset']) {
  if (!payload.required.includes(field)) throw new Error(`completion contract missing ${field}`);
}
if (schema.$defs.TaskCompletedEvent.allOf[1].properties.type.const !== '3d.task.completed') {
  throw new Error('completion event type changed');
}
NODE

if grep -Eqi 'postgres|UPDATE products|processing completion consumer|GET /catalog|GET /search|VisibilityDetector|flutter|payment|checkout|event_outbox|dead.?letter' \
  services/worker-3d/src/processing_pipeline.rs services/worker-3d/src/runtime.rs; then
  echo "US-026 must not add PostgreSQL mutation, API completion consumption, UI, checkout, outbox, or dead-letter behavior" >&2
  exit 1
fi

cargo fmt --all -- --check
cargo clippy -p worker-3d --all-targets -- -D warnings
cargo test -p worker-3d
bazelisk test //services/worker-3d/...
bazelisk build //services/worker-3d:worker-3d

echo "US-026 verification passed"
