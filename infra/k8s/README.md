# Kubernetes Infrastructure

Kustomize resources for the local K3d `dev` namespace, including PostgreSQL,
MinIO, NATS, Meilisearch, application workloads, and Traefik routing.

The development overlay now deploys a single-node core NATS server with an
internal Service and monitoring health probes. PostgreSQL, MinIO, Meilisearch,
application workloads, persistence, and ingress remain deferred.

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

Verify the NATS deployment in an isolated cluster with:

```bash
bash scripts/verify-us-006.sh
```

Infrastructure stories must add health, persistence, routing, and rollback
proof before their services are marked complete.
