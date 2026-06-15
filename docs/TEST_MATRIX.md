# Test Matrix

Product behavior and selected stories now exist. Durable proof status is the
source of truth and must be queried through the Harness CLI:

```bash
scripts/bin/harness-cli query matrix
```

Do not maintain a second hand-edited story table in this file.

## Proof Meanings

- Unit: pure domain and application behavior.
- Integration: cross-module, storage, provider, event, or structural behavior.
- E2E: user-visible browser or mobile workflows.
- Platform: deployment, native shell, cluster, or runtime checks not proven
  below.

Stories may be implemented without every proof column when their packet
explains why a layer is not applicable or remains a later-phase requirement.

