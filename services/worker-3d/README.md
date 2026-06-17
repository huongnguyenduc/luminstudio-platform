# 3D Worker

Rust worker responsible for consuming processing tasks, generating optimized
GLB and 360 assets, uploading outputs, and publishing
completion events.

Phase 1 provides an executable with a parsed concurrency setting and structured
startup output. Phase 2 adds the first worker-side task intake foundation:
v1 `3d.task.created` parsing and validation, the `lumin.3d.task.created`
subject constant, a core-NATS subscriber boundary, and a `SourceAssetReader`
handoff for the referenced source GLB. The first optimization boundary uses the
pinned Rust `meshopt` crate to simplify supported GLB 2.0 indexed triangle
primitives and rebuild a smaller valid asset while preserving scene, node, and
material metadata. The next rendering boundary selects Blender 4.5 LTS
headless automation and defines a deterministic 24-frame, 6-by-4 JPEG sprite
sheet. The runtime processing boundary now reads source objects through the
official MinIO Rust SDK, runs optimization and Blender rendering, uploads the
optimized GLB and sprite sheet, and publishes `3d.task.completed` through core
NATS. The development worker image now packages the worker binary, Blender, and
the render script for K3d deployment, and the live smoke runs the worker through
the Go API, NATS, MinIO, and completion consumer boundaries. Production Blender
image hardening and retry/dead-letter behavior remain deferred.

Run native tests:

```bash
cargo test -p worker-3d
```

Run the complete story verification from the repository root:

```bash
bash scripts/verify-us-002.sh
```

Run the Phase 2 task intake verification from the repository root:

```bash
bash scripts/verify-us-023.sh
```

Optimize a local GLB with the default 50% triangle target:

```bash
cargo run -p worker-3d --bin optimize-glb -- input.glb output.glb
```

Run the mesh optimization story verification from the repository root:

```bash
bash scripts/verify-us-024.sh
```

Run the 360-degree sprite rendering verification from the repository root:

```bash
bash scripts/verify-us-025.sh
```

Run the runtime processing and output upload verification from the repository
root:

```bash
bash scripts/verify-us-026.sh
```

Run the worker K3d deployment and live processing smoke verification from the
repository root:

```bash
bash scripts/verify-us-028.sh
```
