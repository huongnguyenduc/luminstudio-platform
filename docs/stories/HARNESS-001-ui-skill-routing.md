# HARNESS-001 Route UI Design Skills

## Status

implemented

## Lane

normal

## Goal

Make the installed web and mobile UI skills discoverable and give future agents
a deterministic way to select compatible design guidance without weakening
product, architecture, accessibility, or validation contracts.

## Acceptance Criteria

- `AGENTS.md` directs user-visible web/mobile work through a UI skill guide.
- The guide maps installed skills to purpose-specific Harness capabilities and
  documents compatibility, precedence, platform boundaries, and proof rules.
- Context rules retrieve the guide and selected skill files for UI tasks.
- An idempotent repository script registers the providers in a new or existing
  Harness database, and Harness reports them as present.
- Generated concepts are explicitly separated from implementation proof.

## Validation

- Run `bash scripts/verify-ui-skills.sh`.

## Evidence

- `bash scripts/register-ui-skills.sh`: pass twice; all configured providers
  remained registered and `present` without duplicate-name failures.
- `bash scripts/verify-ui-skills.sh`: pass; lock membership, skill paths,
  routing documentation, capabilities, and diff formatting were valid.
- `scripts/bin/harness-cli story verify HARNESS-001`: pass.
