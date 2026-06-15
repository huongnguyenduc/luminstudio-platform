# Shared Types

Source-of-truth location for portable API, NATS event, OpenAPI, Protobuf, and
JSON Schema contracts shared across components.

Generated language bindings should be produced by build rules and consumed by
components; generated output must not replace the contract source.

## Contracts

- `contracts/v1/common.schema.json`: shared identifiers, object references, and
  mesh color configuration.
- `contracts/v1/product.schema.json`: initial product administration draft and
  persisted product record shapes.
- `contracts/v1/events.schema.json`: NATS event envelope and payload shapes for
  `product.updated`, `3d.task.created`, and `3d.task.completed`.
