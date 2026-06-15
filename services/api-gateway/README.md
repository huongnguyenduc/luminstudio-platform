# API Gateway

Go service responsible for business APIs, PostgreSQL state, MinIO access
coordination, NATS publication/consumption, and Meilisearch synchronization.

Phase 1 currently provides a standard-library HTTP server with `GET /healthz`
and Bazel OCI image targets for Linux amd64 and arm64. It does not select Fiber
versus Gin or introduce product endpoints, persistence, messaging, object
storage, or search connectivity.

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
