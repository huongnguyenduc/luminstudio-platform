# 0011 Use The Rust Meshopt Crate

Date: 2026-06-15

## Status

Accepted

## Context

The worker needs mesh simplification, but a project-owned C/C++ wrapper would
add an ABI, allocation ownership rules, duplicate build integration, and a
larger memory-safety test surface. The meshoptimizer upstream documentation
recommends the `meshopt` crate for Rust consumers. The user explicitly approved
using that crate and removing the project-owned FFI requirement.

## Decision

Pin `meshopt` 0.6.2 in `services/worker-3d` and call its idiomatic Rust API.
Keep GLB parsing, supported-layout validation, output reconstruction, naming,
and processing errors owned by the worker. Do not add a Lumin-specific C ABI or
vendor meshoptimizer sources under `packages/third-party`.

## Alternatives Considered

1. Maintain a project-owned C/C++ wrapper around meshoptimizer. Rejected because
   it duplicates the crate's integration work and expands the unsafe boundary.
2. Invoke `gltfpack` as a subprocess. Rejected because process management and
   filesystem handoff are unnecessary for the first in-process worker slice.
3. Implement mesh simplification in pure Rust. Rejected because it would replace
   a mature upstream algorithm without a product requirement to do so.

## Consequences

Positive:

- Worker code uses a small Rust-facing API recommended by meshoptimizer.
- Cargo and Bazel can compile and test the same pinned dependency.
- Lumin owns GLB contract validation without owning a custom native ABI.

Tradeoffs:

- The crate compiles bundled native meshoptimizer sources in its build script.
- The first implementation intentionally supports a constrained GLB layout and
  rejects shared, sparse, or non-triangle index data.
- Dependency upgrades require license, build, fixture, and regression review.

## Follow-Up

- Expand supported GLB layouts only with fixtures and explicit validation.
- Select the 360-degree headless renderer in a separate decision and story.
