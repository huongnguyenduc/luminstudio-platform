# Shared Contract Version 1

This directory contains the first source-of-truth contracts for product
administration, customer catalog/search responses, GLB asset intake, and
asynchronous processing events.

The files are JSON Schema sources. Generated language bindings may be added by
later stories, but generated output must not replace these contract sources.

## Files

- `common.schema.json`: shared identifiers, object storage references, and mesh
  color configuration.
- `product.schema.json`: initial product draft, persisted product record,
  customer catalog item, and catalog search response shapes.
- `events.schema.json`: NATS event envelope and payload shapes for
  `product.updated`, `3d.task.created`, and `3d.task.completed`.

## Non-Goals

These contracts do not implement HTTP routes, database migrations, NATS
publication or consumption, worker mesh processing, authorization, or UI
behavior.
