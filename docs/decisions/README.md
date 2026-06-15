# Decisions

Decision records explain why important product, architecture, or harness choices
were made.

Use `docs/templates/decision.md` when adding a new decision.

After adding a markdown decision file, create the durable decision row:

```bash
scripts/bin/harness-cli decision add \
  --id 0008-auth-boundary \
  --title "Auth Boundary" \
  --doc docs/decisions/0008-auth-boundary.md
```

The current CLI does not update an existing decision id. Keep later markdown
edits consistent with the accepted decision, and record required durable-row
changes in the Harness backlog until an update/upsert command exists.

Trace fields such as `--decisions` summarize task-level choices. They do not
count as the Harness decision log.

Add a decision when:

- A locked technical choice changes.
- A product rule changes meaningfully.
- A validation requirement is added, removed, or weakened.
- A high-risk feature chooses one design over another.
- Auth, authorization, data ownership, audit/security, or API behavior changes.
- The source-of-truth hierarchy changes.
