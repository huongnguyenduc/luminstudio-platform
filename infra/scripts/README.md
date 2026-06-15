# Infrastructure Scripts

Repeatable local and CI commands for image loading, Kustomize deployment,
service smoke checks, backup/restore, and operational verification.

Scripts must be idempotent where practical and must fail clearly rather than
silently accepting a partial cluster state.

Manage the local K3d development cluster with:

```bash
infra/scripts/dev-cluster.sh up
infra/scripts/dev-cluster.sh status
infra/scripts/dev-cluster.sh delete
```

Set `LUMIN_CLUSTER_NAME` only for isolated verification or parallel local
clusters. The default cluster is `lumin-dev`.

Build the Go API image matching the Docker host architecture and import it into
the existing development cluster before applying the workload:

```bash
infra/scripts/dev-cluster.sh create
infra/scripts/import-api-image.sh
infra/scripts/dev-cluster.sh apply
```

Run the isolated NATS platform verification with:

```bash
bash scripts/verify-us-006.sh
```
