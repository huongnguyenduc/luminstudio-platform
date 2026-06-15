# 3D Worker

Rust worker responsible for consuming processing tasks, invoking reviewed C++
FFI, generating optimized GLB and 360 assets, uploading outputs, and publishing
completion events.

Phase 1 provides a stdlib-only executable with a parsed concurrency setting and
structured startup output. It does not introduce NATS, MinIO, FFI code, native
dependencies, a renderer, or 3D processing behavior.

Run native tests:

```bash
cargo test -p worker-3d
```

Run the complete story verification from the repository root:

```bash
bash scripts/verify-us-002.sh
```
