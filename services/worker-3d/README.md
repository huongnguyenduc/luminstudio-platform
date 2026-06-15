# 3D Worker

Rust worker responsible for consuming processing tasks, invoking reviewed C++
FFI, generating optimized GLB and 360 assets, uploading outputs, and publishing
completion events.

Phase 0 does not introduce FFI code, native dependencies, a renderer, or worker
runtime behavior.

