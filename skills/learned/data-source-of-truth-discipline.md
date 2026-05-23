---
name: data-source-of-truth-discipline
description: For systems writing BOTH an append-only event log AND a derived aggregate cache, treat the log as authoritative + the cache as recoverable. Document the reconstruction path. Pin field semantics. Filter test artifacts during recovery. Source = log; cache = ephemeral optimization.
type: learned-pattern
applies-to: [data-design, event-logging, caches, recovery, observability]
projects: [all]
severity: warning
phase: [design, build, post-incident]
trigger: [append-only-log, derived-cache, aggregate-stats, recovery-needed]
last-validated: 2026-05-22
archetypes: [infra-config, telegram-bot, content-pipeline]
---

# Pattern: Treat the Append-Only Log as Truth, the Cache as Optimization

When a system writes BOTH an append-only event log (JSONL, NDJSON, audit trail) AND a derived aggregate cache (TSV, summary table, materialized view), the log is the durable record of truth. The cache is a performance optimization that can be reconstructed.

## Why this matters

Caches get stomped. Tests with backup-restore-on-trap patterns leak when killed by `SIGKILL` or task cancellation. A schema migration breaks reads. A concurrent write races. The cache is the part that goes wrong; the log is the part that survives.

**Concrete incident (2026-05-21 Phase 7.4 live smoke):** `~/.claude/data/bake-off-stats.tsv` got stomped from 5 real rows to header-only because tests 03 + 07 used a `BACKUP=$(mktemp); cp live $BACKUP; trap cleanup EXIT` pattern. Two slow test runs got killed mid-execution; their traps didn't fire; the live file was left in test-mutated state.

Recovery path worked: 13 JSONL records in `bake-off-log.jsonl` were parsed by a Python reconstruction script; all 5 real TSV rows recovered exactly. The log was the only durable record. Without it, the data would have been lost.

## The five rules

1. **Treat the log as authoritative.** It's append-only → safe under concurrency, recoverable when the cache is lost. Atomic appends preserve history.

2. **Treat the cache as ephemeral.** Even if the cache is "the real production target" (what apps READ at runtime), it remains a performance optimization on top of the log. Don't let "cache is fast" blur into "cache is truth."

3. **Document the recovery path.** Add a `tools/reconstruct-cache.py` (or shell equivalent) that rebuilds the cache from the log. Keep it in version control. Test it before you need it.

4. **Pin field semantics at the writer site.** During recovery, undocumented field meanings become bugs. Example: `winner_idx` could be zero-based or one-based. Without a docstring at the writer, reconstruction guesses — and guesses silently corrupt the recovered cache. Add the docstring at the writer: `# winner_idx is zero-based into candidates[].`

5. **Filter test artifacts during reconstruction.** If tests write to the same log (anti-pattern, but it happens — Phase 7.4 test 04's atomicity stress leaked 10 testskill records into the live JSONL), the reconstruction script must filter known test-fixture skill names. Better fix upstream: tests should use an env-var-overridable log path so they never touch the live log at all (see `test-fixtures-must-not-write-live-data-files.md`).

## How to apply

**When designing a new event-log + cache pair:**

- Put the log first in the design doc. Define its schema before the cache schema.
- Define the reconstruction function at design time, not after the first incident. Even a docstring describing the algorithm is enough.
- Pin every ambiguous field at the writer site (zero/one-based, inclusive/exclusive bounds, UTC/local time, etc.).

**When reviewing existing code:**

- Find every `*.tsv`, `*.csv`, `*-stats.*`, `*-cache.*` file that derives from a log. For each, ask: where's the reconstruction tool? If the answer is "we'd have to reverse-engineer the aggregation," that's tech debt.
- Audit: do tests write to the same log or cache file? If yes, refactor to env-var-overridden paths.

**When recovering from an incident:**

- Don't repair the cache by hand. Run the reconstruction tool. If the tool doesn't exist, write it FIRST (and then check it in).
- Diff the reconstructed cache against the pre-incident state if you have one. Exact match means recovery worked. Mismatch means either the recovery is buggy or the cache was already drifted.

## Where this applies in the current codebase

- `~/.claude/data/bake-off-stats.tsv` (derived) ← `~/.claude/data/bake-off-log.jsonl` (truth) — active example.
- `~/.claude/data/agent-eval.jsonl` (Phase 7.6 LLM-judge log) — currently no derived cache; if one is added later, follow this pattern.
- `~/.claude/data/plugin-update-reports/*.md` (Phase 7.7b) — reports are themselves derived from `installed_plugins.json` + live `git ls-remote`. The reports are emphemeral by design; deleting them doesn't lose information.

## Related patterns

- `test-fixtures-must-not-write-live-data-files.md` — root cause for the incident that exposed this pattern. Tests with backup-restore-on-trap are unsafe under SIGKILL.
- `never-fabricate.md` — recovery must work from real data, not invented field values. The docstring at the writer is what makes "real" possible.
- `audit-trail-before-speculative-fix.md` — same principle on a different axis: write the audit trail first, derive everything else from it.

Sourced from `feedback_jsonl_log_is_source_of_truth_tsv_is_derived_cache.md`.
