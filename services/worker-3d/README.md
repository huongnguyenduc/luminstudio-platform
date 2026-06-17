# 3D Worker

The Rust service that does the heavy graphics work. It consumes processing
tasks from NATS, optimizes source meshes, renders 360° previews, uploads the
results to MinIO, and publishes completion events. Keeping this work out of the
API gateway is what lets the customer-facing API stay fast.

## Pipeline

1. **Intake** — subscribe to `lumin.3d.task.created` and validate the v1
   `3d.task.created` event, then read the referenced source GLB from MinIO.
2. **Optimize** — use the pinned [`meshopt`](https://crates.io/crates/meshopt)
   crate to simplify supported GLB 2.0 indexed triangle primitives, rebuilding
   a smaller valid asset while preserving scene, node, and material metadata.
3. **Render** — drive Blender 4.5 LTS headlessly to produce a deterministic
   24-frame, 6×4 JPEG sprite sheet for the 360° preview.
4. **Publish** — upload the optimized GLB and sprite sheet to MinIO and emit
   `3d.task.completed` over core NATS for the gateway to record.

The development worker image packages the worker binary, Blender, and the render
script for K3d deployment.

**Deferred:** production Blender image hardening and retry/dead-letter behavior.

## Development

```bash
# Run native tests
cargo test -p worker-3d

# Optimize a local GLB (default 50% triangle target)
cargo run -p worker-3d --bin optimize-glb -- input.glb output.glb
```

## Verification

Each boundary ships with an executable verification script under `scripts/`.
Run any of them from the repository root:

```bash
bash scripts/verify-us-002.sh   # worker foundation
bash scripts/verify-us-023.sh   # task intake & validation
bash scripts/verify-us-024.sh   # mesh optimization
bash scripts/verify-us-025.sh   # 360° sprite rendering
bash scripts/verify-us-026.sh   # runtime processing & output upload
bash scripts/verify-us-028.sh   # K3d deployment & live processing smoke
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for boundary rules and
[packages/shared-types](../../packages/shared-types/README.md) for the event
contracts this worker consumes and produces.
