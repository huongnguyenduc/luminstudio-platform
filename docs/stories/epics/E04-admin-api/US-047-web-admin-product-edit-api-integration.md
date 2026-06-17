# US-047 Web Admin Product Edit API Integration

## Status

implemented

## Lane

normal

## Product Contract

The React Web Admin lets administrators edit an existing product draft through
the existing Go API `PUT /admin/products/{id}` boundary. The edit workflow
starts from a selected product record, hydrates the v1 draft fields into the
same validated form shape used for creation, submits one full-replacement
draft, and refreshes the product list after a successful update.

The Web Admin remains behind the Go API gateway. It does not connect directly
to PostgreSQL, MinIO, NATS, or Meilisearch.

This story does not add product delete, source GLB upload, authentication,
authorization, live backend proof, backend contract changes, or live browser
E2E automation.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- Product rows expose an edit action without replacing the existing list or
  create workflows.
- Selecting a product renders an edit form hydrated from the selected v1
  `ProductRecord` fields: name, slug, description, display price, optional
  compare-at price, category JSON, information section JSON, and mesh color
  configuration JSON.
- The edit form uses the same client-side validation as product creation before
  submit.
- Submitting sends `PUT /admin/products/{id}` through the configured API base
  URL with `Content-Type: application/json` and `Accept: application/json`.
- Success state reports the updated product and refreshes the list from
  `GET /admin/products`.
- Failure state renders the API or validation error inline without using
  `window.alert()`.
- The UI remains application-style admin layout with responsive behavior at
  desktop and mobile widths.
- Tests cover update route construction, product-record form hydration, update
  submission, selected edit state rendering, inline success/failure states, and
  the existing list/create behavior without requiring a live backend.
- Verification proves Web Admin TypeScript, Vitest, Vite build, Bazel test and
  build targets, docs updates, route alignment, and non-goals.

## Design Notes

- Commands: `bash scripts/verify-us-047.sh`.
- Queries: Web Admin continues to call `GET /admin/products`.
- Commands: Web Admin adds `PUT /admin/products/{id}`.
- API: no backend routes are added; this story consumes the `US-019` route.
- Tables: none.
- Domain rules: Web Admin clients stay behind the Go API gateway and consume
  the versioned JSON shape exposed by the API.
- UI surfaces: React Web Admin product edit form, product create form, and
  product list page.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-047 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Vitest covers route construction, draft parsing, record hydration, update states, and product rows. |
| Integration | Web Admin TypeScript, Vite build, Bazel test, Bazel build, browser render verification, and static verifier pass. |
| E2E | Not required; no live backend or live browser E2E automation is required for durable story proof. |
| Platform | Not required; no K3d, storage, search, database, or messaging behavior changes. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `bash scripts/verify-us-047.sh` passed.
- `pnpm --dir apps/web-admin test` passed with 18 Vitest assertions covering
  route construction, product draft parsing, product-record form hydration,
  create POST behavior, update PUT behavior, create states, edit states, and
  product rows.
- `pnpm --dir apps/web-admin build` passed with TypeScript and Vite production
  build proof.
- `bazelisk test //apps/web-admin:web-admin-test` passed.
- `bazelisk build //apps/web-admin:web-admin` passed.
- Static verification found Web Admin `PUT /admin/products/{id}` route
  construction, selected-record edit hydration, v1 product draft form fields,
  client-side validation, inline edit success/failure states, docs updates, and
  story non-goals.
- Browser render verification passed with mocked `GET /admin/products` and
  `PUT /admin/products/prod_12345678` at 1440x1000 and 390x844. Screenshots
  were saved under `reports/us-047/`; both viewports rendered the selected edit
  workflow with no console errors and no horizontal overflow, and the proof
  captured the submitted v1 draft body with price, categories, information
  sections, and mesh color configuration.
