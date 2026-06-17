# Shared Contract Version 1

This directory contains the first source-of-truth contracts for product
administration, customer catalog/search responses, backend cart snapshots, GLB
asset intake, and asynchronous processing events.

The files are JSON Schema sources. Generated language bindings may be added by
later stories, but generated output must not replace these contract sources.

## Files

- `common.schema.json`: shared identifiers, object storage references, and mesh
  color configuration, including optional customer-facing labels for allowed
  finish colors.
- `product.schema.json`: initial product draft, persisted product record,
  product category, customer catalog item, category list, catalog search
  response, product detail response, cart upsert request, and cart record
  shapes.
- `events.schema.json`: NATS event envelope and payload shapes for
  `product.updated`, `3d.task.created`, and `3d.task.completed`.

## Binary Asset Routes

- `GET /catalog/products/{id}/sprite` streams an `image/jpeg` 360-degree sprite
  for completed products whose catalog item contains a `lumin-360-sprites`
  object reference. The response body is binary, so it is documented here
  rather than modeled as a JSON Schema object.
- `GET /catalog/products/{id}/model?tier=low|high` streams
  `model/gltf-binary` for completed products. Low tier reads the optimized GLB
  object from `lumin-optimized-glb`; high tier reads the source GLB object from
  `lumin-source-glb`. Clients receive gateway routes, not direct MinIO or
  signed object URLs.

## Non-Goals

These contracts do not implement HTTP routes, database migrations, NATS
publication or consumption, worker mesh processing, authorization, or UI
behavior.
