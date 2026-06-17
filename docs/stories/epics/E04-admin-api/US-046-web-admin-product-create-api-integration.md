# US-046 Web Admin Product Create API Integration

## Status

implemented

## Lane

normal

## Product Contract

The React Web Admin lets administrators create product drafts through the
existing Go API `POST /admin/products` boundary. The create workflow collects
the v1 product draft fields needed by the current contract: name, slug,
description, display price, optional compare-at price, category JSON,
information section JSON, and optional mesh color configuration JSON.

The Web Admin validates obvious client-side input before submit, sends one JSON
product draft to the Go API, renders submitting, success, and failure states,
and refreshes the product list after a successful create. The created product
record remains displayed through the existing list UI.

The Web Admin remains behind the Go API gateway. It does not connect directly
to PostgreSQL, MinIO, NATS, or Meilisearch.

This story does not add product edit, delete, source GLB upload,
authentication, authorization, live backend proof, backend contract changes, or
live browser E2E automation.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- The Web Admin renders a product create form alongside the existing product
  list without replacing the list workflow.
- The form builds a v1 `ProductDraft` JSON body with `price`, `categories`,
  `informationSections`, and `meshColorConfig` fields matching the shared
  contract.
- Client-side validation catches required text fields, slug format, positive
  integer-cent pricing, uppercase three-letter currency, compare-at price
  ordering, and malformed JSON before submit.
- Submitting posts to `POST /admin/products` through the configured API base
  URL with `Content-Type: application/json` and `Accept: application/json`.
- Success state reports the created product and refreshes the list from
  `GET /admin/products`.
- Failure state renders the API or validation error inline without using
  `window.alert()`.
- The UI remains application-style admin layout with responsive behavior at
  desktop and mobile widths.
- Tests cover create route construction, draft parsing, validation failures,
  submit state rendering, success state rendering, and non-empty product rows
  without requiring a live backend.
- Verification proves Web Admin TypeScript, Vitest, Vite build, Bazel test and
  build targets, docs updates, route alignment, and non-goals.

## Design Notes

- Commands: `bash scripts/verify-us-046.sh`.
- Queries: Web Admin continues to call `GET /admin/products`.
- Commands: Web Admin adds `POST /admin/products`.
- API: no backend routes are added; this story consumes the `US-017` route.
- Tables: none.
- Domain rules: Web Admin clients stay behind the Go API gateway and consume
  the versioned JSON shape exposed by the API.
- UI surfaces: React Web Admin product create form and product list page.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-046 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Vitest covers route construction, draft parsing, validation, create states, and product rows. |
| Integration | Web Admin TypeScript, Vite build, Bazel test, Bazel build, browser render verification, and static verifier pass. |
| E2E | Not required; no live backend or live browser E2E automation is required for durable story proof. |
| Platform | Not required; no K3d, storage, search, database, or messaging behavior changes. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `bash scripts/verify-us-046.sh` passed.
- `pnpm --dir apps/web-admin test` passed with 13 Vitest assertions covering
  route construction, product draft parsing, validation failures, create POST
  behavior, create states, and product rows.
- `pnpm --dir apps/web-admin build` passed with TypeScript and Vite production
  build proof.
- `bazelisk test //apps/web-admin:web-admin-test` passed.
- `bazelisk build //apps/web-admin:web-admin` passed.
- Static verification found Web Admin `POST /admin/products` route
  construction, v1 product draft form fields, client-side validation, inline
  create success/failure states, docs updates, and story non-goals.
- Browser render verification passed with mocked `GET /admin/products` and
  `POST /admin/products` at 1440x1000 and 390x844. Screenshots were saved under
  `reports/us-046/`; both viewports rendered the create form and product list
  with no console errors and no horizontal overflow. The desktop interaction
  proof also captured the submitted v1 draft body with price, categories,
  information sections, and mesh color configuration.
