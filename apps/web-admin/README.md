# Web Admin

React + Vite administration surface for product CRUD, GLB upload, mesh color
configuration, and dynamic product information sections.

Phase 1 provides the executable React + Vite shell, native checks, and Bazel
build/test targets. Product UI design, routes, API clients, and administration
workflows still belong to selected Phase 2 stories.

Native verification:

```bash
pnpm --dir apps/web-admin test
pnpm --dir apps/web-admin build
```

Bazel verification:

```bash
bazelisk test //apps/web-admin/...
bazelisk build //apps/web-admin:web-admin
```
