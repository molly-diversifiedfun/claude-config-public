---
name: mass-rewrite-mechanics
description: When rewriting ≥3 existing files in parallel, batch-Read ALL targets first, then batch-Write. Write tool errors with 'File not read yet' if you skip the read step. For N-copy byte-identical sync (multi-skill bundles), enforce with sentinel grep + md5 + `bash -n` drift script.
type: learned-pattern
applies-to: [process, verification, multi-skill-bundle, drift-detection]
projects: [all]
severity: warning
phase: [build, deploy]
last-validated: 2026-05-19
archetypes: [always-on]
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

---

## Variant: When N copies must stay byte-identical (multi-skill bundles)

### Rule
When code or telemetry must be byte-identical across N skill surfaces (e.g. free ABP + 3 paid skills), three enforcement layers together produce confident "no drift":

1. **Sentinel string** (e.g. `ABP_TELEMETRY_SENTINEL_v1`) present exactly once per surface SKILL.md. A `grep -c` surfaces missing surfaces immediately.
2. **Byte-identical helper file** copied into each surface's `scripts/` dir. md5 across all N must match a single hash. (No symlinks — each skill ships its real copy per the paid-skill-separation contract.)
3. **`bash -n` parse on every embedded fenced-bash block** inside each SKILL.md. Catches syntax bugs like `& ; }` that grep misses.

### Why
Stage 8 of the 2026-05-19 buyer-signals ship caught 4 separate `& ; }` syntax errors in 4 surfaces because the drift script ran `bash -n` on embedded snippets. Without that third layer, "drift contract clean" would have shipped 4 broken paid-skill install events to prod.

### How to apply
Any future multi-skill bundle (or any case where N copies of a file must stay synced) gets a drift script with all three layers. Bake the script into `/ship` Stage 9 smoke gate. Working reference: `~/github/claude-skills/ai-build-partner/scripts/check-event-drift.sh`.

### Trigger
Multi-surface deploys where the same helper/snippet/event-firing code must exist verbatim in N places. Anything with a paid-skill-separation contract.

### Origin
2026-05-19 ABP buyer-signals ship — Stage 8 reviewer caught 4 syntax errors across 4 SKILL.md files. Cross-refs: [[verify-before-commit]] (drift check is part of the verify loop), `feedback_paid_skill_detection_needs_real_separation.md` (why separation matters in the first place).
