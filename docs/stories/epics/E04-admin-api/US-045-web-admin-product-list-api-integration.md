# US-045 Web Admin Product List API Integration

## Status

implemented

## Lane

normal

## Product Contract

The React Web Admin consumes the existing Go API administrator read boundary
and renders persisted product records from `GET /admin/products`. The product
list is the first product workflow in the Web Admin beyond the Phase 1 shell.
It presents product identity, slug, display price, category labels, processing
status, and update time from the API response.

The Web Admin remains behind the Go API gateway. It does not connect directly
to PostgreSQL, MinIO, NATS, or Meilisearch.

This story does not add create, edit, delete, source GLB upload, auth,
authorization, live backend proof, or live browser E2E automation.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- The Web Admin fetches `GET /admin/products` from the configured API base URL
  and parses v1 `ProductRecord` response fields used by the UI.
- The page renders loading, empty, failure/retry, and ready states.
- Ready state shows product name, slug, display price, categories, processing
  status, updated time, and product identity without exposing direct platform
  service access.
- The UI uses application-style admin layout and responsive behavior rather
  than a marketing shell.
- Tests cover API route construction, state rendering, currency formatting, and
  non-empty product rows without requiring a live backend.
- Verification proves Web Admin TypeScript, Vitest, Vite build, Bazel test and
  build targets, docs updates, route alignment, and non-goals.

## Design Notes

- Commands: `bash scripts/verify-us-045.sh`.
- Queries: Web Admin calls `GET /admin/products`.
- API: no new backend routes are added; this story consumes the `US-018` route.
- Tables: none.
- Domain rules: Web Admin clients stay behind the Go API gateway and consume
  the versioned JSON shape exposed by the API.
- UI surfaces: React Web Admin product list page.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-045 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Vitest covers route construction, rendering states, price formatting, and product rows. |
| Integration | Web Admin TypeScript, Vite build, Bazel test, Bazel build, and static verifier pass. |
| E2E | Not required; no live backend or browser automation is required for durable story proof. |
| Platform | Not required; no K3d, storage, search, database, or messaging behavior changes. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `bash scripts/verify-us-045.sh` passed.
- `pnpm --dir apps/web-admin test` passed with 7 Vitest assertions covering
  route construction, state rendering, price formatting, and product rows.
- `pnpm --dir apps/web-admin build` passed with TypeScript and Vite production
  build proof.
- `bazelisk test //apps/web-admin:web-admin-test` passed.
- `bazelisk build //apps/web-admin:web-admin` passed.
- Static verification found Web Admin `GET /admin/products` route construction,
  loading/empty/error/ready states, responsive admin layout styles, docs
  updates, and story non-goals.
- Browser render verification passed with mocked `GET /admin/products` data at
  1440x1000 and 390x844. Screenshots were saved under `reports/us-045/`; both
  viewports rendered product rows with no console errors and no horizontal
  overflow.
