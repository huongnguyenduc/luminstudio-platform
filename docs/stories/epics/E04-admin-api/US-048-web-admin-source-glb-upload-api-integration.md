# US-048 Web Admin Source GLB Upload API Integration

## Status

implemented

## Lane

normal

## Product Contract

The React Web Admin lets administrators upload one source `.glb` file for a
selected product through the existing Go API
`POST /admin/products/{id}/source-glb` boundary. The workflow starts from the
selected product record, validates that a non-empty `.glb` file is selected,
submits multipart form data with the `source` field, renders inline progress,
success, and failure states, and refreshes the product list after a successful
upload so queued processing state is visible.

The Web Admin remains behind the Go API gateway. It does not connect directly
to PostgreSQL, MinIO, NATS, or Meilisearch.

This story does not add product delete, authentication, authorization, backend
contract changes, signed object URLs, live backend proof, or live browser E2E
automation.

## Relevant Product Docs

- `docs/product/admin-and-processing.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- Selecting a product renders an upload panel alongside the existing edit
  workflow without replacing the existing list, create, or edit workflows.
- The upload panel shows current source asset and processing status from the v1
  `ProductRecord` when available.
- Client-side validation rejects missing files, non-`.glb` filenames, empty
  files, and products without mesh color configuration before submit.
- Submitting sends `POST /admin/products/{id}/source-glb` through the
  configured API base URL as multipart form data with field name `source` and
  `Accept: application/json`.
- Success state reports the uploaded product and refreshes the list from
  `GET /admin/products`.
- Failure state renders the API or validation error inline without using
  `window.alert()`.
- The UI remains application-style admin layout with responsive behavior at
  desktop and mobile widths.
- Tests cover upload route construction, upload validation, multipart POST
  behavior, selected product upload rendering, inline success/failure states,
  and the existing list/create/edit behavior without requiring a live backend.
- Verification proves Web Admin TypeScript, Vitest, Vite build, Bazel test and
  build targets, docs updates, route alignment, and non-goals.

## Design Notes

- Commands: `bash scripts/verify-us-048.sh`.
- Queries: Web Admin continues to call `GET /admin/products`.
- Commands: Web Admin adds multipart `POST /admin/products/{id}/source-glb`.
- API: no backend routes are added; this story consumes the `US-022` route.
- Tables: none.
- Domain rules: source uploads require mesh color configuration before the API
  queues processing.
- UI surfaces: React Web Admin selected product panel, product edit form, source
  upload panel, and product list page.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-048 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Vitest covers route construction, source upload validation, multipart POST behavior, upload states, and product rows. |
| Integration | Web Admin TypeScript, Vite build, Bazel test, Bazel build, browser render verification, and static verifier pass. |
| E2E | Not required; no live backend or live browser E2E automation is required for durable story proof. |
| Platform | Not required; no K3d, storage, search, database, or messaging behavior changes. |
| Release | Not required. |

## Harness Delta

None planned.

## Evidence

- `bash scripts/verify-us-048.sh` passed.
- `pnpm --dir apps/web-admin test` passed with 24 Vitest assertions covering
  route construction, product draft parsing, product-record form hydration,
  create POST behavior, update PUT behavior, source upload multipart POST
  behavior, source upload validation, selected product upload states, and
  product rows.
- `pnpm --dir apps/web-admin build` passed with TypeScript and Vite production
  build proof.
- `bazelisk test //apps/web-admin:web-admin-test` passed.
- `bazelisk build //apps/web-admin:web-admin` passed.
- Static verification found Web Admin `POST /admin/products/{id}/source-glb`
  route construction, multipart `source` file upload, selected-product upload
  rendering, client-side file validation, inline upload success/failure states,
  docs updates, and story non-goals.
- Browser render verification passed with mocked `GET /admin/products` and
  `POST /admin/products/prod_12345678/source-glb` at 1440x1000 and 390x844.
  Both viewports rendered the selected upload workflow with no console errors,
  no framework overlay, no horizontal overflow, and captured multipart form
  data containing `source.glb` in the `source` field.
