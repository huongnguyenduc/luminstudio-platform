# US-003 Build The Web Admin Shell

## Status

implemented

## Lane

normal

## Product Contract

As a platform developer, I need a pinned Node.js and React + Vite build target
so that Phase 1 proves the Web Admin component can build and test before product
administration workflows are introduced.

## Relevant Product Docs

- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Bzlmod declares `rules_js` and a pinned downloaded Node.js toolchain.
- The pnpm workspace has a committed lockfile with exact Web Admin dependencies.
- `//apps/web-admin:web-admin` builds a production Vite bundle.
- Native TypeScript, Vite, and Vitest checks pass.
- Bazel executes the Web Admin test target successfully.
- The rendered shell identifies the boundary without adding product routes,
  API clients, forms, or administration workflows.

## Design Notes

- Commands: `bash scripts/verify-us-003.sh`.
- Queries: none.
- API: none.
- Tables: none.
- Domain rules: none; this story is component bootstrap only.
- UI surfaces: one non-interactive build-status shell.
- Build: `aspect_rules_js` 3.2.1, Node.js 22.20.0, pnpm 10.17.0,
  React 19.2.7, Vite 6.4.3.

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit | The React shell renders its Phase 1 boundary copy. |
| Integration | pnpm and Bazel execute tests and produce the Vite bundle. |
| E2E | Not applicable; no product workflow exists. |
| Platform | Bazel builds with the pinned downloaded Node.js toolchain. |
| Release | Deferred until deployable images and K3d resources exist. |

## Harness Delta

- Added a repeatable story verification command.
- Confirmed `rules_js` requires root and package-level npm link targets for a
  pnpm workspace.

## Evidence

- `pnpm --dir apps/web-admin test`: pass; 1 render test passed.
- `pnpm --dir apps/web-admin build`: pass; TypeScript and Vite production build
  completed.
- `bazelisk test //apps/web-admin/...`: pass; Web Admin Vitest target passed.
- `bazelisk build //apps/web-admin:web-admin`: pass; production bundle emitted
  under `bazel-bin/apps/web-admin/dist`.
- `bash scripts/verify-us-003.sh`: pass.
- Browser production preview: pass at 1280x720 and 390x844 with no horizontal
  overflow or console warnings/errors.
