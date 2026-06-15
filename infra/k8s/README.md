# Kubernetes Infrastructure

Kustomize resources for the local K3d `dev` namespace, including PostgreSQL,
MinIO, NATS, Meilisearch, application workloads, and Traefik routing.

Phase 0 does not create deployable manifests or claim that any cluster service
is running. Infrastructure stories must add health, persistence, routing, and
rollback proof.

