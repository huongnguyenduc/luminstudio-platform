# Web Admin

The React + Vite administration surface for Lumin Studio. Merchants use it to
author products and upload the 3D source models that drive the customer catalog.
Every read and write goes through the Go API gateway — the admin app never
touches infrastructure directly.

## Features

- **Product list** — read-only catalog loaded from `GET /admin/products`, with
  loading, empty, failure, and ready states.
- **Create & edit** — product authoring through `POST /admin/products` and
  `PUT /admin/products/{id}`, with hydrated draft values, client-side
  validation, and submitting/success/failure states.
- **Source GLB upload** — upload a product's source `.glb` through
  `POST /admin/products/{id}/source-glb` to trigger 3D processing, with file
  validation and uploading/success/failure states.
- **Mesh color configuration** and dynamic product information sections.

## Development

```bash
# Install dependencies (from the repository root)
pnpm install

# Run the dev server, unit tests, and production build
pnpm --dir apps/web-admin dev
pnpm --dir apps/web-admin test
pnpm --dir apps/web-admin build
```

The app talks to the Go gateway; point it at a running API during local
development (see the root [README](../../README.md#run-the-local-platform)).

## Verification

```bash
# Bazel build & test
bazel test //apps/web-admin/...
bazel build //apps/web-admin:web-admin

# Story verification (from the repository root)
bash scripts/verify-us-045.sh   # product list
bash scripts/verify-us-046.sh   # product creation
bash scripts/verify-us-047.sh   # product editing
bash scripts/verify-us-048.sh   # source GLB upload
```
