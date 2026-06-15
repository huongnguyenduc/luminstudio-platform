# 3D Worker

Rust worker responsible for consuming processing tasks, invoking reviewed C++
FFI, generating optimized GLB and 360 assets, uploading outputs, and publishing
completion events.

Phase 1 provides an executable with a parsed concurrency setting and structured
startup output. Phase 2 adds the first worker-side task intake foundation:
v1 `3d.task.created` parsing and validation, the `lumin.3d.task.created`
subject constant, a core-NATS subscriber boundary, and a `SourceAssetReader`
handoff for the referenced source GLB. It does not yet introduce meshoptimizer,
360-degree rendering, processed asset uploads, completion event publication, or
live K3d worker proof.

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
