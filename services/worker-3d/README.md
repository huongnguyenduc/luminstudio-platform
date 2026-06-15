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
material metadata. It does not yet introduce 360-degree rendering, processed
asset uploads, completion event publication, runtime subscriber wiring, or live
K3d worker proof.

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
