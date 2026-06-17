#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk cargo grep shasum; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-025" >&2
    exit 1
  fi
done

blender_bin="${BLENDER_BIN:-}"
if [[ -z "$blender_bin" ]]; then
  if command -v blender >/dev/null 2>&1; then
    blender_bin="$(command -v blender)"
  elif [[ -x /Applications/Blender.app/Contents/MacOS/Blender ]]; then
    blender_bin=/Applications/Blender.app/Contents/MacOS/Blender
  else
    echo "Blender is required to verify US-025; set BLENDER_BIN" >&2
    exit 1
  fi
fi

bash -n scripts/verify-us-025.sh

story_text="$(cat docs/stories/epics/E07-3d-processing/US-025-worker-360-sprite-rendering.md)"
decision_text="$(cat docs/decisions/0012-use-blender-for-360-sprites.md)"
admin_text="$(cat docs/product/admin-and-processing.md)"
renderer_text="$(cat services/worker-3d/scripts/render_360_sprite.py)"
contract_text="$(cat services/worker-3d/src/sprite_renderer.rs)"

grep -q 'US-025 Worker 360-Degree Sprite Rendering' <<<"$story_text"
grep -q 'Use Blender For 360-Degree Sprites' <<<"$decision_text"
grep -q 'Blender 4.5 LTS' <<<"$decision_text"
grep -q '24-frame JPEG sprite sheet' <<<"$story_text"
grep -q 'SPRITE_FRAME_COUNT: usize = 24' <<<"$contract_text"
grep -q 'SPRITE_COLUMNS: usize = 6' <<<"$contract_text"
grep -q 'SPRITE_FRAME_SIZE: usize = 160' <<<"$contract_text"
grep -q 'pub fn sprite_object_key' <<<"$contract_text"
grep -q 'BLENDER_EEVEE_NEXT' <<<"$renderer_text"
grep -q 'bpy.ops.import_scene.gltf' <<<"$renderer_text"
grep -q "Blender's headless CLI" <<<"$admin_text"
grep -q '360-degree renderer' <<<"$admin_text"

if grep -Eqi 'lumin-optimized-glb|lumin-360-sprites|3d\.task\.completed|TaskCompleted|PutObject|NATSSubscriber|TcpStream|POST /|GET /catalog|GET /search|VisibilityDetector|flutter|BLoC|payment|checkout|event_outbox' \
  services/worker-3d/src/sprite_renderer.rs services/worker-3d/scripts/render_360_sprite.py; then
  echo "US-025 must not add uploads, completion events, runtime messaging, UI, checkout, or outbox behavior" >&2
  exit 1
fi

cargo fmt --all -- --check
cargo clippy -p worker-3d --all-targets -- -D warnings
cargo test -p worker-3d
bazelisk test //services/worker-3d/...
bazelisk build //services/worker-3d:scripts/render_360_sprite.py

temporary_dir="$(mktemp -d -t lumin-us025)"
trap 'rm -rf "$temporary_dir"' EXIT
first="$temporary_dir/pet-tag-first.jpg"
second="$temporary_dir/pet-tag-second.jpg"

render() {
  "$blender_bin" --background --factory-startup --disable-autoexec \
    --python-exit-code 1 \
    --python services/worker-3d/scripts/render_360_sprite.py -- \
    resources/pet_tag.glb "$1" --frames 24 --columns 6 --size 160
}

render "$first" | tee "$temporary_dir/first.log"
render "$second" | tee "$temporary_dir/second.log"

test -s "$first"
grep -q '"width": 960' "$temporary_dir/first.log"
grep -q '"height": 640' "$temporary_dir/first.log"
first_sha="$(shasum -a 256 "$first" | awk '{print $1}')"
second_sha="$(shasum -a 256 "$second" | awk '{print $1}')"
test "$first_sha" = "$second_sha"

echo "sprite sha256: $first_sha"
echo "US-025 verification passed with $($blender_bin --version | head -1)"
