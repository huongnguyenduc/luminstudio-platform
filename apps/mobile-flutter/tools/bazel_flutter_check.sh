#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${FLUTTER_HOME:-}" ]]; then
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi
if [[ -n "${HOME:-}" ]]; then
  export PATH="$HOME/flutter/bin:$PATH"
fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

for command in cp dart flutter; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required for the Bazel Flutter check" >&2
    exit 1
  fi
done

if [[ -z "${TEST_SRCDIR:-}" || -z "${TEST_WORKSPACE:-}" || -z "${TEST_TMPDIR:-}" ]]; then
  echo "bazel_flutter_check.sh must be run by bazel test" >&2
  exit 1
fi

source_dir="$TEST_SRCDIR/$TEST_WORKSPACE/apps/mobile-flutter"
work_dir="$TEST_TMPDIR/mobile-flutter"

rm -rf "$work_dir"
mkdir -p "$work_dir"
cp -R -L "$source_dir/." "$work_dir/"

rm -rf "$work_dir/.dart_tool" "$work_dir/build" "$work_dir/.idea"

cd "$work_dir"

flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/us040_capture_test.dart --update-goldens
flutter test
