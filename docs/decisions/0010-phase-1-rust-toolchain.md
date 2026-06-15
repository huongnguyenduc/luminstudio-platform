# 0010 Pin The First Phase 1 Rust Toolchain

Date: 2026-06-15

## Status

Accepted

## Context

Epic E01 requires an executable Rust worker target. The repository needs a
reproducible compiler and Bazel rule version without prematurely adding the
worker's NATS, MinIO, C++ FFI, or 3D processing dependencies.

## Decision

Use `rules_rust` 0.70.0 with the downloaded Rust 1.95.0 toolchain and Rust 2024
edition. Keep the initial worker stdlib-only and make configuration parsing the
only startup boundary in this story.

## Alternatives Considered

1. Use the locally installed Rust toolchain, rejected because it would make Bazel builds host-dependent.
2. Pin Rust 1.96.0, rejected because `rules_rust` 0.70.0 does not publish explicit support for it.
3. Add NATS and MinIO now, rejected because service integration belongs to later Phase 1 stories.

## Consequences

Positive:

- Cargo and Bazel can validate the same dependency-free worker package.
- Invalid startup configuration is rejected before runtime integrations exist.

Tradeoffs:

- Rust 1.95.0 is one stable release behind Rust 1.96.0 as of this decision.
- The executable proves startup only and is not yet a long-running event worker.

## Follow-Up

- Add worker messaging, storage, FFI, and processing behavior only in selected stories with shared contracts and integration proof.
