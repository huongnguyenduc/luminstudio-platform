#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk cargo file grep node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-024" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-024.sh

story_text="$(cat docs/stories/epics/E07-3d-processing/US-024-worker-glb-mesh-optimization.md)"
decision_text="$(cat docs/decisions/0011-use-rust-meshopt-crate.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
worker_text="$(cat services/worker-3d/src/glb_optimizer.rs)"
worker_cargo_text="$(cat services/worker-3d/Cargo.toml)"
notices_text="$(cat docs/THIRD_PARTY_NOTICES.md)"

grep -q 'US-024 Worker GLB Mesh Optimization' <<<"$story_text"
grep -q 'meshopt = "0.6.2"' <<<"$worker_cargo_text"
grep -q 'Use The Rust Meshopt Crate' <<<"$decision_text"
grep -q 'upstream-recommended Rust `meshopt` crate' <<<"$admin_text"
grep -q 'pub fn optimize_glb' <<<"$worker_text"
grep -q 'pub fn optimized_object_key' <<<"$worker_text"
grep -q 'optimizes_pet_tag_fixture_and_preserves_contract_names' <<<"$worker_text"
grep -q 'meshoptimizer is copyright (c) 2016-2026 Arseny Kapoulkine' <<<"$notices_text"

if grep -Eqi 'extern "C"|#include|bindgen|C\+\+ FFI wrapper' \
  services/worker-3d/src/*.rs services/worker-3d/src/bin/*.rs \
  docs/product/admin-and-processing.md docs/ARCHITECTURE.md; then
  echo "US-024 must not add a project-owned C/C++ FFI boundary" >&2
  exit 1
fi

cargo fmt --all -- --check
cargo clippy -p worker-3d --all-targets -- -D warnings
cargo test -p worker-3d
bazelisk test //services/worker-3d/...
bazelisk build //services/worker-3d:optimize-glb

output="$(mktemp -t lumin-pet-tag-low).glb"
trap 'rm -f "$output"' EXIT
cargo run -q -p worker-3d --bin optimize-glb -- resources/pet_tag.glb "$output"

file "$output" | grep -q 'glTF binary model, version 2'
test "$(wc -c < "$output")" -lt "$(wc -c < resources/pet_tag.glb)"

node - "$output" <<'NODE'
const fs = require('fs');
const buffer = fs.readFileSync(process.argv[2]);
const jsonLength = buffer.readUInt32LE(12);
const document = JSON.parse(buffer.subarray(20, 20 + jsonLength).toString().trim());
const text = JSON.stringify(document);
for (const required of ['Tag_Base', 'Tag_Text', 'Base_Mat', 'Text_Mat']) {
  if (!text.includes(required)) throw new Error(`optimized fixture lost ${required}`);
}
const counts = document.meshes.flatMap((mesh) =>
  mesh.primitives.map((primitive) => document.accessors[primitive.indices].count),
);
if (counts.length !== 2 || counts[0] >= 15342 || counts[1] >= 6582) {
  throw new Error(`fixture index counts were not reduced: ${counts.join(',')}`);
}
NODE

echo "US-024 verification passed"
