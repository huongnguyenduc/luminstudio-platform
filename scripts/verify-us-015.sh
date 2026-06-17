#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-015" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-015.sh

node <<'NODE'
const fs = require("fs");
const path = require("path");

const contractDir = path.join("packages", "shared-types", "contracts", "v1");
const files = [
  "common.schema.json",
  "product.schema.json",
  "events.schema.json",
];

for (const file of files) {
  JSON.parse(fs.readFileSync(path.join(contractDir, file), "utf8"));
}
NODE

contract_text="$(cat packages/shared-types/contracts/v1/*.json packages/shared-types/contracts/v1/README.md)"
story_text="$(cat docs/stories/epics/E04-admin-api/US-015-phase-2-contracts.md)"
admin_doc="$(cat docs/product/admin-and-processing.md)"
roadmap_doc="$(cat docs/product/roadmap.md)"

for required in \
  'MeshColorConfig' \
  'lumin-source-glb' \
  'lumin-optimized-glb' \
  'lumin-360-sprites' \
  'product.updated' \
  '3d.task.created' \
  '3d.task.completed' \
  'correlationId' \
  'ProductDraft' \
  'ProductRecord' \
  'ProductUpdatedEvent' \
  'TaskCreatedEvent' \
  'TaskCompletedEvent'; do
  grep -q "$required" <<<"$contract_text"
done

grep -q 'contracts_v1' packages/shared-types/BUILD.bazel
grep -q 'US-015 Define Phase 2 Product, Asset, And Event Contracts' <<<"$story_text"
grep -q 'This story does not add HTTP routes, database migrations, UI behavior, NATS' <<<"$story_text"
grep -q 'shared contract source now starts with JSON Schema' <<<"$admin_doc"
grep -q 'US-015 Define Phase 2 Product, Asset, And Event Contracts' <<<"$roadmap_doc"

if grep -Eqi 'CREATE TABLE|ALTER TABLE|/upload|router\.|HandleFunc|authorization|auth|nats\.Connect|subscribe|publish|meshoptimizer|headless renderer' \
  packages/shared-types/contracts/v1/*.json; then
  echo "US-015 must not add runtime API, database, auth, NATS client, or worker processing behavior" >&2
  exit 1
fi

bazelisk build //packages/shared-types:contracts_v1

echo "US-015 verification passed"
