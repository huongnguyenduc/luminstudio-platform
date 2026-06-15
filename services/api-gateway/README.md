# API Gateway

Go service responsible for business APIs, PostgreSQL state, MinIO access
coordination, NATS publication/consumption, and Meilisearch synchronization.

Phase 1 currently provides a standard-library HTTP server with independent
`GET /healthz` liveness and `GET /readyz` platform-readiness endpoints plus
Bazel OCI image targets for Linux amd64 and arm64. Readiness checks PostgreSQL,
MinIO, NATS, and Meilisearch without introducing product schema, buckets,
indexes, event contracts, or product endpoints.

Run native tests:

```bash
go test ./...
```

Run the complete story verification from the repository root:

```bash
bash scripts/verify-us-001.sh
```

Verify OCI packaging and the K3d deployment from the repository root:

```bash
bash scripts/verify-us-010.sh
```

Verify platform connectivity and readiness behavior from the repository root:

```bash
bash scripts/verify-us-011.sh
```
