---
name: mass-rewrite-mechanics
description: When rewriting ≥3 existing files in parallel, batch-Read ALL targets first, then batch-Write. Write tool errors with 'File not read yet' if you skip the read step.
type: learned-pattern
applies-to: [process, verification]
projects: [all]
severity: warning
phase: [build]
last-validated: 2026-05-12
---

# Pattern: Read-before-Write for Mass File Operations

## Rule
When rewriting ≥3 existing files in parallel, **batch-Read all targets first**, then batch-Write.

```
# WRONG — will fail on existing files
[Write(path1), Write(path2), Write(path3)]  ← 7/8 fail with "File not read yet"

# CORRECT
[Read(path1, limit:3), Read(path2, limit:3), Read(path3, limit:3)]  ← parallel step 1
[Write(path1, content), Write(path2, content), Write(path3, content)] ← parallel step 2
```

`limit: 3` is enough — the tool just needs the file to appear in conversation history. For brand-new files (path doesn't exist), Write works directly.

## Trigger
Any mass-rewrite job: agent file updates, config rewrites, bulk template generation, anywhere you're launching parallel Writes on paths that might already exist.

## Origin
2026-04-07 agent-setup phase 1 — tried to batch 8 Writes without Reads. 7/8 failed. Cost a full extra round-trip. Saved to memory as `feedback_write_requires_read.md`.
