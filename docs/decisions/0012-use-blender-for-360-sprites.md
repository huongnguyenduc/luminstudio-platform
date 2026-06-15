# 0012 Use Blender For 360-Degree Sprites

Date: 2026-06-15

## Status

Accepted

## Context

The worker must turn supported GLB product assets into repeatable 360-degree
JPEG sprite sheets without adding rendering logic to the Go API or clients.
The renderer needs GLB import, material support, camera and lighting control,
headless execution, and scripting suitable for a worker container.

Blender documents command-line background rendering and Python automation as
supported workflows. Blender 4.5 is an LTS release supported until July 2027:

- https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html
- https://developer.blender.org/docs/release_notes/

## Decision

Use Blender's headless CLI and Python API as the 360-degree sprite renderer.
Target Blender 4.5 LTS for the worker image and keep the repository script
compatible with later 5.x releases when practical. Use EEVEE for the initial
rendering boundary, a fixed camera orbit and lighting setup, 24 square frames,
and a 6-by-4 JPEG sprite sheet.

Determinism means identical bytes for repeated renders with the same GLB,
script, Blender build, platform, and render configuration. Cross-version or
cross-driver byte identity is not part of this story.

Blender remains an external worker executable. It is not linked into the Rust
process, served to clients, or distributed as a repository-owned binary.

## Alternatives Considered

1. Build a custom Rust renderer on `wgpu`. Rejected because GLB materials,
   lighting, camera behavior, image encoding, and headless GPU portability
   would become project-owned rendering infrastructure.
2. Use a browser and Three.js in headless Chromium. Rejected because it adds a
   browser runtime and JavaScript rendering surface to the Rust worker.
3. Use Blender Cycles. Deferred because the initial catalog sprite does not
   require path-traced output and EEVEE has a smaller render-time cost.

## Consequences

Positive:

- The worker uses a mature GLB importer and scriptable render pipeline.
- Camera, lighting, frame count, grid shape, and JPEG settings are explicit.
- The renderer can run as an isolated subprocess in a later runtime story.

Tradeoffs:

- The worker image must include a pinned Blender build and its runtime size.
- Render output may change across Blender, EEVEE, GPU driver, or platform
  upgrades; upgrades require fixture review and renewed deterministic proof.
- Untrusted GLB processing must run with worker resource and process limits in
  a later deployment story.

## Follow-Up

- Package Blender 4.5 LTS in the worker image.
- Wire the Rust task processor to optimization and sprite subprocesses.
- Upload both outputs and publish `3d.task.completed` in later stories.
