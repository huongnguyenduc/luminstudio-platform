# US-044 Flutter Bazel Build And Test Boundary

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer application has a Bazel-owned validation boundary that
can run the same native Flutter dependency, formatting, analysis, and test
checks already used by the mobile stories. The boundary copies the app into a
Bazel test temporary directory before running Flutter commands so dependency
resolution and generated files do not mutate the repository source tree.

This story does not add checkout, payments, authentication, authorization,
backend cart APIs, inventory checks, signed object URLs, production release
packaging, live backend proof, live device proof, or new customer-visible
behavior.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- `apps/mobile-flutter` defines a Bazel source boundary for the Flutter app.
- `apps/mobile-flutter` defines a Bazel test target that runs
  `flutter pub get`, `dart format --set-exit-if-changed lib test`,
  `flutter analyze`, the existing US-040 golden refresh, and `flutter test`.
- The Bazel test target runs in a copied temporary app directory instead of
  writing `.dart_tool` or `build` output into the source checkout.
- The Bazel runner discovers a local Flutter SDK from `FLUTTER_HOME`, the
  developer home directory, or common package-manager binary paths before
  running checks inside Bazel's test environment.
- `.bazelrc` passes `PATH`, `HOME`, and optional `FLUTTER_HOME` into Bazel
  tests for this local CLI-backed Flutter validation boundary.
- The Bazel test is tagged `local` and `no-sandbox` because Flutter may update
  SDK cache files outside the execroot before a hermetic Flutter toolchain is
  selected.
- The story verifier proves the native Flutter checks and the Bazel mobile
  target with `bazel test //apps/mobile-flutter:mobile-flutter-test`.
- Product docs and story backlog no longer describe Flutter Bazel rules as
  deferred for the implemented customer app boundary.
- No checkout, payment, auth, inventory, backend cart, signed URL, production
  packaging, live backend, live device, or user-visible workflow behavior is
  added.

## Design Notes

- Commands: a repo-local Bazel test rule delegates to the accepted native
  Flutter command set after copying the app into `TEST_TMPDIR`.
- Queries: none.
- API: none.
- Tables: none.
- Domain rules: no product or commerce domain behavior changes.
- UI surfaces: none.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-044 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | `flutter test` passes through native verification and the Bazel test wrapper. |
| Integration | Static verifier confirms Bazel target wiring, temp-copy behavior, docs, story, and non-goals. |
| E2E | Not required; no live backend, live device, checkout, payment, auth, or customer workflow behavior changes. |
| Platform | Not required; no K3d or deployment behavior changes. |
| Release | Not required; no production Flutter packaging or hermetic Flutter toolchain is introduced. |

## Harness Delta

None planned.

## Evidence

- `flutter pub get` resolved dependencies for `apps/mobile-flutter`.
- `dart format --set-exit-if-changed lib test` passed for
  `apps/mobile-flutter`.
- `flutter analyze` passed for `apps/mobile-flutter`.
- `flutter test` passed for `apps/mobile-flutter` with 33 tests.
- `bazelisk build //apps/mobile-flutter:mobile-flutter-sources` passed.
- `bazelisk test //apps/mobile-flutter:mobile-flutter-test` passed.
- `bash scripts/verify-us-044.sh` passed.
