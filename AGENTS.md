# Agent Instructions

## Lumin Studio Project Rules

- Treat `SPEC.md` as source input, not the living product contract.
- Read the relevant files under `docs/product/` before changing behavior.
- Keep browser/mobile clients behind the Go API boundary; they must not access
  PostgreSQL, MinIO, NATS, or Meilisearch directly.
- Keep heavy 3D processing in `services/worker-3d`; the API coordinates work
  through events and owns relational state changes.
- Use `packages/shared-types` for versioned API, event, and schema contracts.
- Phase 0 is structural only. Do not claim component builds, K3d services, or
  end-to-end flows work until a story adds and verifies them.

<!-- HARNESS:BEGIN -->
## Harness

This repo uses Harness. Before work, read:

- `README.md`
- `docs/HARNESS.md`
- `docs/FEATURE_INTAKE.md`
- `docs/ARCHITECTURE.md`
- `docs/CONTEXT_RULES.md`
- `docs/TOOL_REGISTRY.md`
- `scripts/bin/harness-cli query matrix` on macOS/Linux, or `.\scripts\bin\harness-cli.exe query matrix` on Windows

Use the Rust Harness CLI at `scripts/bin/harness-cli` on macOS/Linux or
`scripts/bin/harness-cli.exe` on Windows as the main operational tool. Before a
step that could use an external tool, run `scripts/bin/harness-cli query tools
--capability <name> --status present` to see what is equipped; an absent
capability is a clean skip.
<!-- HARNESS:END -->
