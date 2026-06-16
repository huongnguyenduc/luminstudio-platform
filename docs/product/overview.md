# Product Overview

## Product

Lumin Studio is a 3D e-commerce platform that lets administrators publish
configurable 3D products and lets customers discover, inspect, customize, and
add those products to a local cart on mobile devices.

## Actors

- **Administrator:** creates and edits products, uploads one high-quality GLB
  source, defines configurable mesh colors, and manages dynamic product detail
  sections.
- **Customer:** browses and searches the catalog, previews 360-degree imagery,
  interacts with 3D models, selects colors, and manages a cart.
- **Platform operator/developer:** builds and runs the monorepo, local K3d
  services, event pipeline, and deployment automation.
- **3D processing system:** converts source assets into delivery variants and
  publishes completion events.

## Product Goals

- Keep heavy 3D work outside the synchronous API request path.
- Accept one high-quality source model and derive optimized delivery assets.
- Deliver typo-tolerant catalog search with low perceived latency.
- Adapt 3D asset quality to mobile device capability.
- Preserve clear component boundaries in a multi-language monorepo.

## Current Scope

- Admin product management and 3D upload configuration.
- Event-driven search synchronization and 3D processing.
- Mobile catalog, search, product detail, customization, local cart, and the
  first backend cart snapshot API.
- Local/dev infrastructure on K3d using PostgreSQL, MinIO, NATS, and
  Meilisearch.

## Explicit Non-Goals

- Authentication and authorization are deferred through Phase 4.
- Checkout, payment processing, inventory checks, order fulfillment, and seller
  settlement are not defined by the current contract.
- Production cloud topology is not selected; the current deployment target is
  the existing local PC/K3d environment.

## Product Constraints

- The web and mobile clients communicate through the Go API gateway.
- Source and processed 3D assets are stored in MinIO.
- PostgreSQL is the relational system of record.
- Meilisearch is a derived search index, not the source of truth.
- NATS carries asynchronous product/search and 3D processing events.
