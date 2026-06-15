#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk cargo grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-023" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-023.sh

story_text="$(cat docs/stories/epics/E07-3d-processing/US-023-worker-task-created-source-download.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
roadmap_text="$(cat docs/product/roadmap.md)"
platform_text="$(cat docs/product/platform-foundation.md)"
root_readme_text="$(cat README.md)"
worker_readme_text="$(cat services/worker-3d/README.md)"
worker_lib_text="$(cat services/worker-3d/src/lib.rs)"
worker_build_text="$(cat services/worker-3d/BUILD.bazel)"
worker_cargo_text="$(cat services/worker-3d/Cargo.toml)"
module_text="$(cat MODULE.bazel)"

grep -q 'US-023 Worker Task Created Source Download' <<<"$story_text"
grep -q '3d.task.created' <<<"$story_text"
grep -q 'SourceAssetReader' <<<"$story_text"
grep -q 'worker-side' <<<"$story_text"
grep -q 'without implementing' <<<"$story_text"

for required in \
  'worker now parses and validates v1 `3d.task.created` events' \
  'source asset reader' \
  'mesh optimization' \
  '360-degree rendering' \
  'processed asset'; do
  grep -q "$required" <<<"$admin_text"
done

grep -q 'US-023 Worker Task Created Source Download' <<<"$roadmap_text"
grep -q 'US-023' <<<"$platform_text"
grep -q 'bash scripts/verify-us-023.sh' <<<"$root_readme_text"
grep -q 'bash scripts/verify-us-023.sh' <<<"$worker_readme_text"

for required in \
  'pub const TASK_CREATED_SUBJECT: &str = "lumin.3d.task.created"' \
  'pub struct TaskCreatedEvent' \
  'pub struct TaskCreatedPayload' \
  'pub struct ObjectRef' \
  'pub trait SourceAssetReader' \
  'pub struct TaskProcessor' \
  'pub fn parse_task_created_event' \
  'fn validate_task_created_event' \
  'source.bucket != "lumin-source-glb"' \
  'pub struct NATSSubscriber' \
  'parse_nats_msg_length' \
  'Test'; do
  if [[ "$required" == "Test" ]]; then
    continue
  fi
  grep -q "$required" <<<"$worker_lib_text"
done

for required in \
  'fn parses_v1_task_created_event' \
  'fn rejects_wrong_task_created_event_type' \
  'fn rejects_task_created_event_with_unknown_fields' \
  'fn rejects_invalid_mesh_color_config' \
  'fn task_processor_downloads_source_asset_from_event' \
  'fn exposes_task_created_nats_subject'; do
  grep -q "$required" <<<"$worker_lib_text"
done

grep -q 'serde = ' <<<"$worker_cargo_text"
grep -q 'serde_json = ' <<<"$worker_cargo_text"
grep -q '@crates//:defs.bzl' <<<"$worker_build_text"
grep -q 'all_crate_deps' <<<"$worker_build_text"
grep -q 'crate.from_cargo' <<<"$module_text"

if grep -Eqi 'meshoptimizer|3d\.task\.completed|TaskCompleted|lumin-optimized-glb|lumin-360-sprites|PutObject|POST /|GET /catalog|GET /search|VisibilityDetector|flutter|BLoC|payment|checkout|event_outbox|CREATE TABLE.*outbox' \
  services/worker-3d/src/*.rs services/worker-3d/Cargo.toml; then
  echo "US-023 must not add mesh optimization, completion publication, processed uploads, UI, checkout, outbox, or customer routes" >&2
  exit 1
fi

cargo test -p worker-3d
bazelisk test //services/worker-3d/...
bazelisk build //services/worker-3d:worker-3d

echo "US-023 verification passed"
