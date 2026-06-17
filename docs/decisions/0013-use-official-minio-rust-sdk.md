# 0013 Use The Official MinIO Rust SDK

Date: 2026-06-15

## Status

Accepted

## Context

The Rust worker must read source GLBs and upload processed assets to MinIO.
Implementing S3 Signature Version 4, streaming responses, object metadata, and
error handling inside Lumin would create a security-sensitive protocol surface.
The official MinIO Rust SDK provides typed S3-compatible operations and supports
the existing MinIO deployment.

## Decision

Pin `minio` 0.4.0 in `services/worker-3d` and use its typed get/put object APIs.
Build it without TLS features for the current namespace-local HTTP MinIO
endpoint while retaining its default signing implementation. Keep MinIO behind
worker-owned `SourceAssetReader` and `ProcessedAssetStore` ports so processing
logic remains independently testable.

## Alternatives Considered

1. Implement S3 Signature Version 4 and HTTP object operations in the worker.
   Rejected because signing and streaming are mature SDK responsibilities.
2. Invoke the MinIO `mc` CLI from the worker. Rejected because it would add a
   second subprocess dependency and make object metadata/error handling weaker.
3. Use the AWS Rust SDK. Rejected because the official MinIO client is a more
   direct fit for the selected storage service and this bounded operation set.

## Consequences

Positive:

- Source reads and processed writes use an upstream-owned signing and S3 layer.
- The processing pipeline depends on small local ports rather than SDK types.
- Cargo and Bazel compile the same pinned client implementation.

Tradeoffs:

- The SDK adds an async runtime and a larger Rust dependency graph.
- TLS is intentionally excluded until deployment topology requires HTTPS from
  the worker to MinIO.
- SDK upgrades require license, build, object metadata, and integration review.

## Follow-Up

- Prove the adapter against namespace-local MinIO in the worker deployment story.
- Enable and verify TLS features if the runtime storage boundary moves to HTTPS.
