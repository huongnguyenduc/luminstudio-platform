<p align="center">
  <img src="resources/lumin_logo.png" alt="Lumin Studio" width="120" height="120" />
</p>

<h1 align="center">Lumin Studio</h1>

<p align="center">
  An event-driven 3D commerce platform — upload a high-poly model once,
  serve optimized 3D and 360° previews to mobile shoppers automatically.
</p>

<p align="center">
  <img alt="Build" src="https://img.shields.io/badge/build-Bazel-43A047" />
  <img alt="API" src="https://img.shields.io/badge/API-Go%201.26-00ADD8" />
  <img alt="Worker" src="https://img.shields.io/badge/worker-Rust-DEA584" />
  <img alt="Mobile" src="https://img.shields.io/badge/mobile-Flutter%203.9-02569B" />
  <img alt="Admin" src="https://img.shields.io/badge/admin-React%20%2B%20Vite-61DAFB" />
</p>

---

## Overview

Lumin Studio lets merchants upload a single high-quality `.glb` model and
automatically derives everything a storefront needs: a decimated low-poly model
for low-end devices, a 360° sprite-sheet preview, and a searchable catalog
entry. Heavy graphics work runs asynchronously so the customer-facing API stays
fast.

The system is a Bazel-managed monorepo with four surfaces — an admin web app, a
Go API gateway, a Rust 3D worker, and a Flutter customer app — backed by
PostgreSQL, MinIO, NATS, and Meilisearch.

## Architecture

```text
                    ┌──────────────────┐         ┌──────────────────┐
   Admin (React) ──▶│                  │         │                  │
                    │   API Gateway    │◀───────▶│    PostgreSQL    │
 Mobile (Flutter)──▶│       (Go)       │         │  (relational)    │
                    │                  │         └──────────────────┘
                    └───┬───────┬──────┘
                        │       │  publish/subscribe
              object    │       ▼
              storage   │   ┌────────┐   3d.task.created   ┌──────────────┐
                        ├──▶│  NATS  │────────────────────▶│  3D Worker   │
                        │   └────────┘                     │   (Rust)     │
                        ▼        ▲   3d.task.completed      │ meshopt +    │
                   ┌─────────┐   └──────────────────────── │ Blender 360° │
                   │  MinIO  │◀──── processed assets ────── └──────────────┘
                   └─────────┘
                        │   product.updated event
                        ▼
                  ┌─────────────┐
                  │ Meilisearch │  full-text + typo-tolerant catalog search
                  └─────────────┘
```

Clients never touch infrastructure directly — all reads and writes go through
the Go gateway. Heavy 3D processing is isolated in the Rust worker and
coordinated entirely through NATS events. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for layering and boundary rules.

## Tech Stack

| Layer            | Technology                          | Responsibility                                              |
| ---------------- | ----------------------------------- | ----------------------------------------------------------- |
| Build system     | Bazel (Bzlmod)                      | Multi-language build & cache for Go, Rust, JS/TS, and Dart  |
| API gateway      | Go 1.26                             | Business logic, REST API, relational state, event publish   |
| 3D worker        | Rust (`meshopt`) + Blender 4.5 LTS  | Async mesh decimation and headless 360° sprite rendering    |
| Admin web        | React + Vite                        | Product authoring, asset upload, mesh/color configuration   |
| Customer app     | Flutter (BLoC, Clean Architecture)  | Catalog, search, 3D viewer, device-tiered model loading     |
| Database         | PostgreSQL                          | Authoritative relational state                              |
| Object storage   | MinIO                               | Source GLB, optimized GLB, and 360° sprite assets           |
| Message broker   | NATS                                | Async event delivery (3D tasks, search sync)                |
| Search           | Meilisearch                         | Fast, typo-tolerant catalog search                          |
| Platform         | K3d · Traefik · Cloudflare Tunnel   | Local/self-hosted Kubernetes and ingress                    |

## Repository Layout

```text
apps/
  mobile-flutter/    Customer Flutter app (BLoC, Clean Architecture)
  web-admin/         React + Vite admin application
services/
  api-gateway/       Go API and event coordination
  worker-3d/         Rust 3D processing worker
packages/
  shared-types/      Versioned API, event, and JSON-schema contracts
  third-party/       Reviewed native third-party sources
infra/
  k8s/               Kustomize resources for the dev cluster
  scripts/           Deployment and operational scripts
docs/                Product truth, architecture, decisions, and stories
scripts/             Per-story verification scripts and tooling
```

## Getting Started

### Prerequisites

- [Bazel](https://bazel.build/) (version pinned in `.bazelversion`)
- [Docker](https://www.docker.com/) and [k3d](https://k3d.io/) for the local cluster
- [pnpm](https://pnpm.io/) 10 (web admin) and the [Flutter](https://flutter.dev/) 3.9+ SDK (mobile)

### Build

```bash
# Build the entire monorepo
bazel build //...

# Run all unit tests across Go, Rust, JS, and Flutter
bazel test //...
```

### Run the local platform

The full stack (PostgreSQL, MinIO, NATS, Meilisearch, gateway, worker) runs in a
local K3d cluster. Bring it up, then port-forward the gateway:

```bash
kubectl port-forward svc/api-gateway 8080:8080
```

The Flutter app defaults to `LUMIN_API_BASE_URL=localhost:8080`. See
[docs/deploy-self-hosted.md](docs/deploy-self-hosted.md) for the production
self-hosted topology.

## Verification

Each user story ships with an executable verification script under `scripts/`
that proves the corresponding boundary end to end. Run any of them directly:

```bash
# Structural foundation
bash scripts/verify-foundation.sh

# A specific story (e.g. backend cart API foundation)
bash scripts/verify-us-051.sh
```

Some live smoke scripts take an API base URL:

```bash
LUMIN_US053_API_BASE_URL=http://127.0.0.1:8080 bash scripts/verify-us-053.sh
```

The full list of stories and their proof status is tracked via the Harness CLI:

```bash
scripts/bin/harness-cli query matrix
```

## Documentation

| Document | Purpose |
| --- | --- |
| [SPEC.md](SPEC.md) | Original product/technical specification (input material) |
| [docs/product/](docs/product/README.md) | Living product contract — the current source of truth |
| [docs/stories/](docs/stories/README.md) | Selected and in-flight work |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layering, boundaries, and dependency rules |
| [docs/decisions/](docs/decisions) | Architecture Decision Records |
| [AGENTS.md](AGENTS.md) | Contributor and agent working rules |
| [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md) | Dependency attribution |

## Project Status

Lumin Studio is under active development. The core 3D pipeline is operational
end to end: admins create products and upload models through the web admin, the
Rust worker optimizes meshes and renders 360° previews, and the Flutter app
browses, searches, views models in 3D, and manages a backend-synced cart.

**Implemented:** monorepo & local cluster · admin product CRUD · source GLB
upload · event-driven search sync · mesh optimization · 360° rendering ·
customer catalog/search/category APIs · Flutter shell, catalog, 3D viewer,
color configuration, and cart.

**Deferred:** authentication & authorization · checkout, payment & inventory ·
order fulfillment · discount engine · production worker hardening
(retry/dead-letter) · production mobile release packaging.

> Authentication is intentionally out of scope for the current phases to focus
> on the core 3D commerce flow.

## License

Proprietary — © 2026 Lumin Studio. All rights reserved. This is commercial
software; no rights are granted without a separate signed agreement. See
[LICENSE](LICENSE) for terms.
