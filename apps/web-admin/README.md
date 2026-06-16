# Web Admin

React + Vite administration surface for product CRUD, GLB upload, mesh color
configuration, and dynamic product information sections.

Phase 1 provides the executable React + Vite shell, native checks, and Bazel
build/test targets. `US-045` adds the first product workflow: a read-only
product list loaded from the Go API `GET /admin/products` boundary with
loading, empty, failure, and ready states.

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

Story verification:

```bash
bash scripts/verify-us-045.sh
```
