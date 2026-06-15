# 0008 Use Bzlmod For The Monorepo Foundation

Date: 2026-06-15

## Status

Accepted

## Context

`SPEC.md` selects Bazel and allows either a `WORKSPACE` or `MODULE.bazel` root.
Phase 0 needs one dependency model so future language rules and toolchains do
not grow through two parallel configuration systems.

## Decision

Use `MODULE.bazel` and Bzlmod as the primary Bazel dependency model. Component
directories retain native manifests, while Bazel becomes the cross-language
build graph in Phase 1.

Phase 0 creates valid package boundaries but does not select or pin the Go,
Rust, JavaScript, Dart, container, or Kubernetes Bazel rules.

## Alternatives Considered

1. Use legacy `WORKSPACE` dependency declarations. Rejected because new
   foundation work should not create a second dependency model to migrate
   later.
2. Configure all language rules in Phase 0. Rejected because rule versions and
   component targets should be selected with executable Phase 1 validation.
3. Skip Bazel files until applications exist. Rejected because stable package
   boundaries are part of the requested foundation.

## Consequences

Positive:

- Future Bazel dependencies have one source of truth.
- The monorepo package graph exists before component implementation.
- Phase 1 can add toolchains incrementally with explicit proof.

Tradeoffs:

- `bazel build //...` is not yet a valid completion claim.
- Contributors need Bazel/Bazelisk installed before running platform proof.

## Follow-Up

- Phase 1 must select pinned Bazel rules and toolchains.
- Phase 1 must add real build/test targets for web, Go, Rust, and Flutter.

