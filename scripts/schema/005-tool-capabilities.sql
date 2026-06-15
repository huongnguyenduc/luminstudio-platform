-- Harness v0 schema - migration 005
-- Capability-aware external tool discovery and presence checks.

ALTER TABLE tool ADD COLUMN kind TEXT NOT NULL DEFAULT 'cli'
    CHECK(kind IN ('cli','binary','mcp','skill','http'));
ALTER TABLE tool ADD COLUMN capability TEXT;
ALTER TABLE tool ADD COLUMN scan_target TEXT;
ALTER TABLE tool ADD COLUMN status TEXT NOT NULL DEFAULT 'unknown'
    CHECK(status IN ('unknown','present','missing'));
ALTER TABLE tool ADD COLUMN checked_at TEXT;

INSERT INTO schema_version (version) VALUES (5);
