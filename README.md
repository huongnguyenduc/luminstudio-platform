# Lumin Studio

Lumin Studio is a 3D commerce platform composed of an admin web application,
a Go API gateway, an asynchronous Rust/C++ 3D worker, and a Flutter customer
application. PostgreSQL, MinIO, NATS, and Meilisearch provide persistence,
object storage, event delivery, and search.

## Current Status

Phase 0 established the product contract and monorepo foundation. Phase 1 is in
progress: the Go API has an operational health endpoint, and the Rust worker
has an executable startup/configuration target. The React + Vite Web Admin has
an executable build/test target and a non-product shell. A repeatable local
K3d cluster now hosts the labeled `dev` namespace and a healthy namespace-local
NATS service plus persistent PostgreSQL, MinIO, and Meilisearch instances. The
Bazel-built Go API image runs behind a namespace-local Service and exposes
separate liveness and platform-readiness endpoints that prove connectivity to
all four services. 3D processing, product database schema, storage buckets,
NATS publish/subscribe proof, external development routes, and product workflows
have not been implemented yet.

The original [SPEC.md](SPEC.md) is input material. Current product truth lives
under `docs/product/`, selected work lives under `docs/stories/`, and proof
status is queried through the Harness CLI.

## Repository Map

```text
apps/
  mobile-flutter/       Customer Flutter application
  web-admin/            React and Vite administration application
services/
  api-gateway/          Go API and event coordination
  worker-3d/            Rust worker and C++ FFI boundary
packages/
  shared-types/         API, event, and schema contracts
  third-party/          Reviewed native third-party sources
infra/
  k8s/                  Kustomize resources for the dev cluster
  scripts/              Deployment and operational scripts
.agents/skills/         Optional UI design and image-direction skills
```

## Start Here

1. Read [AGENTS.md](AGENTS.md).
2. Read the relevant files under [docs/product](docs/product/README.md).
3. Select or create a story under [docs/stories](docs/stories/README.md).
4. Check proof state with `scripts/bin/harness-cli query matrix`.

Phase 0 structural verification:

```bash
bash scripts/verify-foundation.sh
```

First Phase 1 component verification:

```bash
bash scripts/verify-us-001.sh
```

Rust worker bootstrap verification:

```bash
bash scripts/verify-us-002.sh
```

Web Admin bootstrap verification:

```bash
bash scripts/verify-us-003.sh
```

Kustomize development namespace verification:

```bash
bash scripts/verify-us-004.sh
```

K3d development cluster lifecycle verification:

```bash
bash scripts/verify-us-005.sh
```

NATS development deployment verification:

```bash
bash scripts/verify-us-006.sh
```

PostgreSQL development deployment verification:

```bash
bash scripts/verify-us-007.sh
```

MinIO development deployment verification:

```bash
bash scripts/verify-us-008.sh
```

Meilisearch development deployment verification:

```bash
bash scripts/verify-us-009.sh
```

Go API image and K3d deployment verification:

```bash
bash scripts/verify-us-010.sh
```

Go API platform connectivity verification:

```bash
bash scripts/verify-us-011.sh
```

Bazel is the selected top-level build system. Go, Rust, JavaScript, and OCI
rules now provide executable component and API image targets; Flutter rules and
remaining platform behavior will be added by later stories.
