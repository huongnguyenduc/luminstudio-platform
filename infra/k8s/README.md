# Kubernetes Infrastructure

Kustomize resources for the local K3d `dev` namespace, including PostgreSQL,
MinIO, NATS, Meilisearch, application workloads, and Traefik routing.

The first Phase 1 infrastructure slice provides a renderable Kustomize base and
the `overlays/dev` namespace boundary. It does not deploy workloads or claim
that any cluster service is running.

Render the current development overlay with:

```bash
kubectl kustomize infra/k8s/overlays/dev
```

Infrastructure stories must add health, persistence, routing, and rollback
proof before their services are marked complete.
