# Kubernetes Infrastructure

Kustomize resources for the local K3d `dev` namespace, including PostgreSQL,
MinIO, NATS, Meilisearch, application workloads, and Traefik routing.

The first Phase 1 infrastructure slice provides a renderable Kustomize base and
the `overlays/dev` namespace boundary. The next slice adds a pinned K3d cluster
configuration, but still does not deploy platform or application workloads.

Create the local cluster and apply the development overlay with:

```bash
infra/scripts/dev-cluster.sh up
```

The command targets cluster `lumin-dev` through context `k3d-lumin-dev` without
changing the current Kubernetes context. Inspect or remove it with:

```bash
infra/scripts/dev-cluster.sh status
infra/scripts/dev-cluster.sh delete
```

Render the current development overlay with:

```bash
kubectl kustomize infra/k8s/overlays/dev
```

Infrastructure stories must add health, persistence, routing, and rollback
proof before their services are marked complete.
