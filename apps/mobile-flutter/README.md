<p align="center">
  <img src="assets/branding/lumin_logo.png" alt="Lumin Studio" width="96" height="96" />
</p>

<h1 align="center">Lumin Studio — Mobile</h1>

<p align="center">
  The Flutter customer app for Lumin Studio: browse the catalog, search,
  preview products in 360° and interactive 3D, configure colors, and manage a
  backend-synced cart.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.9%2B-02569B" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.9%2B-0175C2" />
  <img alt="State" src="https://img.shields.io/badge/state-BLoC-13B9FD" />
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%20%C2%B7%20Android-555" />
</p>

---

## Overview

This app is the end-user storefront for the Lumin Studio 3D commerce platform.
It talks to the Go API gateway over HTTP only — it never accesses PostgreSQL,
MinIO, NATS, or Meilisearch directly. On startup it evaluates the device tier
(RAM/OS) to decide whether to load high- or low-poly models, and it renders
360° sprite previews and an interactive 3D viewer for product detail.

## Features

- **Tabbed shell** — Home, Category, and Cart with per-tab scroll and navigation
  state retained across switches.
- **Catalog & search** — paginated product lists with typo-tolerant search,
  plus loading, empty, failure/retry, and clear states.
- **360° preview** — sprite-sheet animation activates when a card stays ≥80%
  visible and idle for ~3 seconds.
- **Product detail** — seller info sections, an interactive rotate/zoom 3D
  viewer, and live material color swatches.
- **Device-tiered models** — selects low/high model tier based on device
  capability.
- **Cart** — add configured items, toggle selection, see live subtotal and
  savings; synced to the backend cart API with a local snapshot as fallback.

## Architecture

The app follows **Clean Architecture**, organized feature-first, with **BLoC
(Cubits)** for state. Each feature is split into three layers:

```text
lib/
  app/                     App composition, theming, dependency wiring
    theme/                 Theme, animations, theme-mode cubit
  features/
    shell/                 Bottom-nav shell and tab state
    catalog/               Home, search, category, product detail
      data/                API client + repository implementations
      domain/              Entities, repository ports, use cases
      presentation/        Views + Cubits
    cart/                  Cart state, persistence, backend sync
      data/ · domain/ · presentation/
  shared/                  Cross-feature widgets, formatting, API helpers
  main.dart                Entry point
```

Dependency rule: `presentation → domain ← data`. Domain holds entities,
repository interfaces, and use cases with no framework dependencies;
`data` implements those ports against the Go API; `presentation` drives Cubits.

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/) SDK 3.9+ (Dart 3.9+)
- An iOS Simulator / Android emulator, or a physical device
- A running Lumin Studio API gateway (see the [root README](../../README.md))

### Configure the API endpoint

The app reads the gateway base URL from a compile-time environment variable,
defaulting to `http://localhost:8080`:

```bash
flutter run --dart-define=LUMIN_API_BASE_URL=http://127.0.0.1:8080
```

### Install & run

```bash
flutter pub get
flutter run            # uses the default localhost:8080 endpoint
```

### Test

```bash
flutter test                       # unit and widget tests
flutter test --update-goldens      # regenerate golden images when UI changes
```

> Golden tests use lazy lists that do not mount off-screen widgets; keep the
> product detail screen lazy and avoid networked fonts/infinite animations in
> tested widgets.

## Verification

Each customer story has an executable verification script at the repository
root. Run them from the repo root (not this directory):

```bash
# App shell, catalog, search, pagination
bash scripts/verify-us-030.sh        # tabbed shell
bash scripts/verify-us-031.sh        # catalog products API
bash scripts/verify-us-032.sh        # search UI
bash scripts/verify-us-033.sh        # pagination / infinite scroll

# Previews, detail, 3D, configuration, cart
bash scripts/verify-us-035.sh        # 360° preview activation
bash scripts/verify-us-037.sh        # product detail + device tier
bash scripts/verify-us-038.sh        # interactive 3D viewer
bash scripts/verify-us-039.sh        # material color selection
bash scripts/verify-us-040.sh        # local cart persistence
bash scripts/verify-us-041.sh        # pricing contract & cart totals
bash scripts/verify-us-043.sh        # category tab API integration
bash scripts/verify-us-044.sh        # Bazel build & test boundary
bash scripts/verify-us-052.sh        # backend cart API integration
```

Live smoke scripts target a running gateway via an env var:

```bash
LUMIN_US050_API_BASE_URL=http://127.0.0.1:8080 bash scripts/verify-us-050.sh
LUMIN_US053_API_BASE_URL=http://127.0.0.1:8080 bash scripts/verify-us-053.sh
```

## Status

Catalog, search, 360° previews, interactive 3D detail, color configuration, and
a backend-synced cart are implemented and proven on the iOS simulator.
Checkout, payment, authentication, inventory, discount engines, and production
release packaging are deferred to later work.
