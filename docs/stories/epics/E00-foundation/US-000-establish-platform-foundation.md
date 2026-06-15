# US-000 Establish Platform Foundation

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need the supplied specification converted into a
living product contract and a stable monorepo skeleton so that Phase 1 work can
be selected, implemented, and verified without relying on a monolithic spec or
inventing package boundaries.

## Relevant Product Docs

- `docs/product/overview.md`
- `docs/product/platform-foundation.md`
- `docs/product/admin-and-processing.md`
- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Product intent from `SPEC.md` is split into indexed, current product docs.
- The roadmap defines Phase 0 and candidate epics for Phases 1-4 without
  creating unselected story packets.
- `MODULE.bazel`, `.bazelrc`, and root/component `BUILD.bazel` files establish
  the package graph declared by the product contract.
- Every top-level app, service, package, and infrastructure boundary has a
  README that states responsibility and non-goals.
- `bash scripts/verify-foundation.sh` validates the required Phase 0 paths.
- Documentation explicitly states that component builds, K3d services, and
  product workflows are not implemented by this story.

## Design Notes

- Commands: `bash scripts/verify-foundation.sh`.
- Queries: none.
- API: no API contract is implemented in Phase 0.
- Tables: no product schema is introduced in Phase 0.
- Domain rules: source-of-truth and component ownership only.
- UI surfaces: package boundaries only; no visual UI is implemented.
- Build: Bzlmod is the primary Bazel dependency model; language rules are
  deferred to Phase 1.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | Not applicable; no domain logic is implemented. |
| Integration | Structural verifier confirms cross-repository paths and docs. |
| E2E | Not applicable; no user-visible flow exists. |
| Platform | `bazel query //...` when Bazel is equipped; currently unavailable locally. |
| Release | Not applicable for the Phase 0 scaffold. |

## Harness Delta

- Added product contract files derived from `SPEC.md`.
- Added Phase 0 and the first normal-lane story packet.
- Added a repeatable structural verification command.
- Recorded the Bzlmod choice as decision `0008`.

## Evidence

- `bash -n scripts/verify-foundation.sh`: pass.
- `bash scripts/verify-foundation.sh`: pass; Bazel package query now passes with
  the Phase 1 pinned Bazel toolchain.
- `cargo metadata --no-deps --format-version 1`: pass for the empty Phase 0
  Rust workspace.
- `scripts/bin/harness-cli story verify US-000`: pass.
- Durable proof: integration `1` and platform `1`; unit and E2E remain `0`
  because Phase 0 contains no product logic or user-visible flow.
