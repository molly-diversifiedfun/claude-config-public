---
name: mempalace-discipline
description: Operational patterns for MemPalace as the sole long-tail memory read path. Wing-filter fail-open, status-check before query, 3-layer architecture, bulk-load with gitleaks gate.
type: learned-pattern
applies-to: [memory, infra, retrieval]
projects: [all]
severity: warning
phase: [pre-flight, retrieval, capture]
trigger: [mempalace-query, memory-keeper-stage-1, agent-pre-flight, bulk-load]
last-validated: 2026-05-20
archetypes: [always-on]
---

# Pattern: MemPalace Operational Discipline

MemPalace is the sole read path for the long-tail memory layer as of Phase 4 (2026-05-19). These are the operational patterns for using it without blowing the migration.

## 3-layer query architecture (final state)

| Layer | Source | Load | Tool |
|---|---|---|---|
| Always-on | `~/.claude/skills/learned/` + CLAUDE.md + CARL rules | Every turn via system prompt | Read / Glob |
| Passive recall | `~/.mempalace/identity.txt` + L1 wake-up | Once per session via SessionStart hook | `mempalace-wrapper.sh --hook=session-start` |
| Retrieval on demand | MemPalace palace (95k+ drawers) | Queried at 3 levels: CARL MEMORY domain, slash command Step 0, per-agent pre-flight | `mcp__mempalace__*` (MCP ONLY — no file fallback) |

The per-project memory dirs (`~/.claude/projects/*/memory/`) are WRITE-ONLY as of Phase 4. Never read them directly — that reintroduces stale on-disk content as authoritative.

## Wing-filter fail-open (REQUIRED for all queries)

MemPalace v3.3.5+ has an index-drift bug: `mcp__mempalace__mempalace_search` with a `wing:` filter sometimes errors with `Error finding id` even when the wing has hundreds of drawers (confirmed on `<your-web-app-1>` wing with 503 drawers on 2026-05-19).

**Rule:** ALWAYS retry without the wing filter on error. Never let a wing-filter error block recall.

```typescript
// pseudocode
try {
  results = await mempalace_search({ query, wing: project })
} catch (e if e.message.includes("Error finding id")) {
  results = await mempalace_search({ query }) // fail-open, accept broader recall
  log_wing_filter_error(project)
}
```

Don't infer absence-of-drawers from a wing-filter error. Verify with `mempalace_list_wings` first if uncertain.

## Status check on palace health

Call `mcp__mempalace__mempalace_status` at session start (per the protocol returned by the tool itself):

- If healthy (returns drawer count + wing/room breakdown) → proceed normally
- If unhealthy (HNSW corruption that didn't self-quarantine, MCP unreachable, etc.) → raise BLOCKED, do NOT fall back to file Glob on memory dirs

The palace has self-healing for HNSW corruption (auto-quarantines `.drift-*` segments). When that triggers, it logs to `~/.claude/logs/mempalace-hooks.log`. If you see frequent quarantines, file an upstream issue. As of 2026-05-19, 3 quarantine events in one day from concurrent writes — palace self-healed each time.

## Auto-mining via Stop hook

The Stop hook (`mempalace-wrapper.sh --hook=stop`) auto-mines the memory dir every ~15 messages. New feedback files land in MemPalace within a session, typically. **Caveat:** the very latest writes lag — the Stop hook fires on `Stop` events, not per-write. If you need a fresh write to be immediately searchable, call `mcp__mempalace__mempalace_add_drawer` directly (auto-mine will dedupe via content hash, so no double-add risk).

## Bulk-load with gitleaks gate (mandatory)

`~/.claude/scripts/mempalace-bulk-load.sh` mines project codebases. **MUST run gitleaks BEFORE mining each project** — the v1 bug (Phase 1.5, 2026-05-19) was a pre-filter that COUNTED matches but didn't SKIP, so secrets ended up indexed across 5+ wings before discovery.

v2 (current) runs `gitleaks detect` per project, SKIPS the whole project on any hit, logs paths to `~/.claude/logs/mempalace-bulk-load-skipped.tsv` (no values), and only mines clean projects.

Self-check guard at top of script (Phase 2 prereq, added 2026-05-19):

```bash
if ! grep -q 'gitleaks detect' "$0"; then
  echo "FATAL: bulk-load script missing gitleaks pre-mine filter" >&2
  exit 99
fi
```

This prevents regression to v1 if someone edits the script and accidentally removes the gitleaks block.

## Query discipline: when to call MemPalace mid-session

Call `mcp__mempalace__mempalace_search` when the prompt mentions:
- A project name (<your-personal-ai-project>, <your-agent-project>, <your-project-1>, <your-web-app-1>, <your-content-pipeline>, etc.) → narrow with wing filter (with fail-open)
- Recall signals: "remember when", "previously", "have we", "did we discuss", "background on", "last time"
- Recipe names: Gumroad, Telegram, Supabase, n8n, Notion, Vercel, Railway, PostHog, Buffer, Stripe
- Conflict signals: "but didn't we decide X?", "I thought we said Y"
- Cross-project pattern hunting: "have I solved this before?"

Skip MemPalace for trivial turns (typos, single-line fixes, pure clarifying questions). The query has real latency cost.

## Surface what you loaded

When MemPalace returns relevant drawers, name them in the first response (path + 1-line summary). This:
1. Lets you correct course if you loaded the wrong context
2. Confirms you actually queried rather than guessing
3. Helps memory-keeper Stage 11 link captures back to source drawers

## Don't re-query for always-on layers

`learned/` patterns and CARL rules are already in your system prompt. Querying MemPalace for them duplicates context and wastes the latency. MemPalace is for the long tail (95k drawers) that don't fit in the system prompt.

## Conflict resolution: trust current state

If MemPalace says X and current code/git state says Y, trust the current state. Update the memory drawer to reflect reality (or mark it stale) rather than acting on outdated info. Memory drift is real — code is the truth; memory is the index.

## Canonical wing taxonomy

**Phase 5 cleanup 2026-05-19.** Authoritative list: `~/github/docs/mempalace-wings.md`.

**Convention:** lowercase, hyphen-separated, no `wing_` prefix, no path strings.

**Target: 22 wings** (14 project + 7 infra + 1 sessions). Pre-Phase-5: 37.

**Project wings (14):** `<your-content-pipeline>`, `<your-web-app-1>`, `<your-agent-project>`, `<your-bot>`, `<your-analytics-dash>`, `<your-video-pipeline>`, `<your-bot-1>`, `<your-project-2>`, `<your-app-3>`, `<your-product-pipeline>`, `<your-marketing-stack>`, `<your-product-pipeline>`, `moa-debate`, `<your-app-rebrand-source>`.

**Infrastructure wings (7):** `claude-config`, `claude-skills`, `claude-code-toolkit`, `claude-config-public`, `learned`, `brainstorms`, `github`.

**Sessions wing (1):** `sessions`.

**Never write to wings:** anything with `wing_` prefix (auto-generated from transcript path normalization — Phase 6 R7 follow-up will patch this upstream); anything matching a path string like `wing-claude-projects-*`; `home`, `Downloads`, `Desktop-*`, `tmp`, or `memory`.

**When in doubt:** consult `~/github/docs/mempalace-wings.md` for the full table including merge-source wings, deletion targets, and dir → wing mappings.

**Yaml drop convention:** every `~/.claude/projects/*/memory/` dir whose project is in the canonical list MUST have a `mempalace.yaml` with `wing: <canonical-name>`. The CLI auto-discovers the yaml when given the dir as a positional arg. `--wing` CLI flag overrides yaml — don't pass it in the wrapper, let yaml win.

## Palace file lock under concurrent miner load

MemPalace uses a process-level file lock on the palace directory for write coordination. Post-Phase 4 + Phase 5 (auto-mine wrapper LIVE on every Stop + PreCompact hook across every active session), **lock contention is the new normal**, not a corner case. Bulk MCP operations against a busy palace hit `palace is held by PID X` errors on roughly 15% of calls.

Two complementary patterns hold the line:

**a) Serialize where you can.** Inside one agent run, drive bulk operations in a single loop — never fan out parallel `mempalace mine` invocations. The `mempalace-wrapper.sh` auto-mine block already serializes (Wave 3 fix). If you're writing a new bulk-operation wrapper, mirror the pattern: one background subshell + watchdog cap, not parallel `&` per dir.

**b) Retry-with-5s-backoff where you can't.** For MCP calls from inside another session (where you can't serialize against the live auto-mine), wrap the call:

```python
# pseudocode
try:
    mempalace_delete_drawer(id)
except LockHeldError:
    sleep(5)
    mempalace_delete_drawer(id)  # one retry
```

In practice every contention this session resolved on a single retry. The auto-mine watchdog has a 20s cap, so by 5s the lock has either released or is about to.

**Never block on the lock.** Don't sleep-loop forever — the watchdog will kill the holder at its cap and your retry succeeds naturally. If a single retry still fails, capture to a ship-dir log and continue with the next item.

**Never touch the lock file directly.** The lock is mempalace's coordination primitive; manually removing it can corrupt the palace index.

**Expected hit rate:** ~15% during bulk MCP operations against a busy palace. If you see >50%, something else is wrong — check `ps aux | grep "mempalace mine"` for a hung miner.

Where this surfaces:
- Bulk wing drain (NIGHT-9 tmp wing: 4126 → 2576 drawers, ~15% retried)
- Mass refile operations (Phase 7 if/when it ships)
- Any MCP `add` / `delete_drawer` / `update_drawer` during a Stop-hook auto-mine window

Source captures: `feedback_palace_file_lock_under_concurrent_miner_load` (steady-state framing + 5s-retry), `feedback_mempalace_palace_file_lock_serialize_mines` (Wave 3 wrapper-side serialize fix — parent pattern).

## `sync --apply` scope-path limitation

`mempalace sync --apply --wing X` does NOT prune every drawer whose source file is missing. Two predicates must both hold:

1. Source file is absent from disk.
2. Source path is inside a known project root (a wing's `source_dir` per `mempalace.yaml`, OR one of mempalace's built-in roots like `~/.claude/projects/*/memory/`, `~/github/*/`, etc.).

Drawers with `/tmp/...` source paths (or any other unusual-root path) fail predicate (2) → bucketed `out_of_scope` → never pruned, regardless of whether the source file still exists. The `--apply` flag only acts on `missing_source`, never `out_of_scope`.

This is conservative-by-default safety: a misconfigured wing yaml could otherwise nuke thousands of drawers in one command. Accept the limitation.

**The workaround when you need to drain an out-of-scope wing:** per-drawer MCP `mempalace_delete_drawer` calls. Paginate via `mempalace_list_drawers --wing tmp --offset N --limit 100`, batch the deletes, expect ~15% to hit the file lock and retry once (per § Palace file lock above). Tonight's NIGHT-9 tmp wing drain went 4126 → 2576 across two agent runs this way.

**Don't:**
- Edit a `mempalace.yaml` to claim `/tmp/` as a source root — the sync engine may then refile / re-mine in surprising ways.
- Manually delete palace index entries — corrupts the palace.

**Possible upstream fix worth proposing if recurring:** `mempalace sync --include-out-of-scope` flag, OR a `mempalace delete-wing` CLI op (currently doesn't exist).

Source capture: `feedback_mempalace_sync_apply_scope_path_limitation` (2026-05-19 NIGHT-9 tmp-drain discovery).

## Rooms standardization is forward-looking only

`mempalace mine` identifies already-filed files by content hash and skips them. Re-mining a dir under a NEW `mempalace.yaml` rooms schema does NOT refile existing drawers — the new schema becomes authoritative for FUTURE captures only.

Phase 5.1 Item 3 (NIGHT-9) edited 17 yamls to the canonical 5-room template (`general` / `decisions` / `problems` / `planning` / `technical`) and re-mined each. Every mine output:

```
Files processed: 0
Files skipped (already filed): N
Drawers filed: 0
```

The mine banner correctly read the new `Rooms:` line; no existing drawer was refiled. Spot-check: `list_drawers wing=<your-agent-project> room=decisions` → 0 drawers; `wing=<your-agent-project> room=general` → 3 drawers (all 548 still in their original room).

**There is no `mempalace mine --force` or `mempalace refile --wing X --from-yaml` op.** Until upstream ships one, the available paths to actually refile are:

1. **Paginated MCP `delete_drawer` + re-mine** — destructive; ~N round trips per wing; expensive but bounded.
2. **Force content-hash change** — add a per-file comment hint (e.g. `_room_hint: decisions`); invasive and brittle.
3. **Wait for natural attrition** — new captures use canonical rooms; existing drawers stay in old rooms.

**How to apply going forward:**
- For any rooms / yaml schema change: commit that the change is forward-looking. Don't promise existing drawers will refile.
- If you NEED existing drawers in new rooms: plan a separate one-time refile ship — treat it like a destructive migration.
- If a downstream feature depends on cross-project room-based retrieval (e.g. cross-project similarity scoring keyed on `room=decisions`), expect empty rooms across the board until natural attrition populates them.

Source capture: `feedback_mempalace_rooms_standardization_is_idempotent` (Phase 5.1 Item 3 discovery).

## Cross-refs

- **Canonical wing taxonomy:** `~/github/docs/mempalace-wings.md` (Phase 5 source of truth — 22 wings)
- CARL MEMORY domain rules: `~/.carl/memory` (8 RULE_* lines) + `~/.carl/manifest` (MEMORY_STATE=active)
- Memory-keeper agent: `~/.claude/agents/memory-keeper.md` (Stage 1 MCP-first; Stage 11 file-write capture target)
- Wing-filter bug source: `feedback_mempalace_wing_filter_error_finding_id.md`
- Phase capture chain: `project_mempalace_phase1.md` → `project_mempalace_phase_1_5.md` → `project_mempalace_phase2_agents_rewired.md` → `project_mempalace_phase3_commands_wired.md` → `project_mempalace_phase4_decommission_complete.md` → `project_mempalace_phase5_wing_taxonomy_cleanup.md`
- Hook wrapper: `~/.claude/hooks/mempalace-wrapper.sh` (SessionStart/Stop/PreCompact)
- Bulk-load script: `~/.claude/scripts/mempalace-bulk-load.sh` (gitleaks-gated, self-check guarded)
