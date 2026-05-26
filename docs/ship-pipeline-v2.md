# Ship Pipeline v3 — Smart Scope-Aware /ship

**Status:** v3 shipped 2026-05-23 (Phase 8.0). Stage 0 scope classifier + explicit per-stage superpowers skill bindings. Calibration follow-ups (Phase 8.0.1-8.0.7 + 8.1 advisory) layered in. v2 (memory-aware, 2026-05-10) — Stage 9 (Deploy + Smoke) gated end-to-end, Stages 1 + 11 (pre-flight + capture) wired. Stages 2-8 + 10 stay as inline reminders.

**Spec:** `~/github/docs/superpowers/specs/2026-05-10-ship-pipeline-v2-design.md` (v2 architecture + decisions + kill criterion).

**Plan:** `~/github/docs/superpowers/plans/2026-05-10-ship-pipeline-v2.md` (v2 22-task implementation log).

## v3 — Stage 0 scope classifier (Phase 8.0)

A Haiku 4.5 call (`scripts/ship-scope-classify.py "<ask>"`, 30s timeout, soft-fails to S on any failure) classifies each ask into one of S / M / L / XL. The scope determines which stages actually run AND which superpowers skills are required at each gate.

**Scope → stage matrix:**

| Scope | Stages run | Required superpowers skills |
|---|---|---|
| **S** | 6 + 9 | `tdd`, `verification-before-completion` |
| **M** | 1 + 2 + 3 + 6 + 7 + 9 + 10 + 11 | `brainstorming`, `tdd`, `verification-before-completion`, `requesting-code-review`, `finishing-a-development-branch` |
| **L** | 1 + 2 + 3 + 4* + 5* + 6 + 7+`subagent-driven-development` + 8 + 9 + 10 + 11 | M's set + `writing-plans` (Stage 4) + `subagent-driven-development` (Stage 7) |
| **XL** | All stages + ADR mandatory in Stage 3 + memory-keeper double-pass | L's set |

\* Stage 4 only if UI; Stage 5 only if open unknowns. **V1 is doc-enforced** — `commands/ship.md` tells the orchestrator to invoke the named Skill at each gate; trust-but-verify. V2 (Phase 8.1, deferred) will hook-enforce via extending `ship-phase-gate.sh` to check Skill tool_use before allowing next Agent dispatch.

**Phase 8.1 (advisory):** `hooks/ship-skill-tracker.sh` logs each Skill invocation to `.ship/<run>/skill-invocations.jsonl`. `/ship-skill-status` reports which expected superpowers fired vs which didn't. Advisory only — never blocks. Catches missed skills without hard-gating.

**Phase 8.0.1-8.0.7 calibration follow-ups:**
- Aggregate floor for `/system-retro` per-mode averages (exclude tiny abandoned sessions <5min / <5 tool calls).
- Mid-session DoD nudge hook — fires before Stop hook can block.
- Scope-classify CONTINUATION rule: vague "step N" asks → inherit prior scope from `.ship/<run>/scope.json` instead of re-classifying as S.
- Pre-commit Stage 10 doc warning when `/ship` run is active and CLAUDE.md/ADRs haven't been updated.
- `/ship-scope-replay` tool — re-classify the first user prompt of recent sessions to validate classifier calibration.
- `/ship-preflight` — probe external dependencies (CLI commands, env vars, files, URLs) before committing.

**Why v3 design:** Phase 7.7c `/system-retro` dogfood showed `/ship` scoring 3.5 on incremental + mode-fit vs raw 4.0 and superpowers 5.0 (n=2 each — small sample but architectural finding stands). `/ship`'s flat 11-stage pipeline was overkill for small asks AND didn't enforce the disciplines superpowers brings. v3 collapses small asks to minimal stages while binding the same disciplines explicitly.

**Kill:** `SHIP_SCOPE=off` (classifier only, defaults to M). 5 unit tests at `~/.claude/test/ship-scope-classify/`.

## v2 — Memory-aware foundation

`/ship` used to be a 12-line orchestration script that called 9 agents in order with no awareness of the memory files or distilled `learned/` patterns it lived alongside. Same mistakes recurred: silent failures committed, scope narrowed, fabrications, blind 4th-deploy iterations.

v2 made `/ship` memory-aware end-to-end:

1. **Pre-flight (Stage 1)** — `memory-keeper` agent detects active project from cwd, infers feature-type tags from the description, glob-loads frontmatter-tagged memory files, writes a `patterns.md` manifest to `.ship/<run>/`. Every downstream agent reads this manifest.
2. **Stage 9 gate** — `ship-phase-gate.sh` hook fires PostToolUse on Agent + Bash when `.ship/<run>/patterns.md` is present. Enforces the 3-deploy rule, observability declaration, and smoke-test section in `deploy-log.md`.
3. **Capture (Stage 11)** — `memory-keeper` scans the session transcript for correction signals, drafts feedback files into `.ship/<run>/draft-feedback/`, asks Q1/Q2/Q3, moves approved drafts into `~/.claude/projects/<workspace>/memory/`, updates MEMORY.md.

## Frontmatter schema (v2)

Every memory + learned file carries:

```yaml
---
name: <slug>
description: <one-line>
type: learned-pattern | feedback | project | reference | user
applies-to: [<tags>]
projects: [<names>] | [all]
severity: blocking | warning | info
phase: [<stages>]
trigger: [<keywords>]            # optional
last-validated: YYYY-MM-DD
---
```

Validated by `~/.claude/scripts/validate-frontmatter.sh`.

## Tag vocabulary (12)

`deploy` · `infra` · `build` · `auth` · `content` · `delegation` · `verification` · `process` · `observability` · `secrets` · `scope` · `memory`

## v1 retrofit scope (18 files)

- 4 always-load blockers (`learned/{systematic-shortcutting,verify-before-commit,delegation-discipline,never-fabricate}.md`)
- 2 deploy-tagged learned (`learned/{deploy-iteration-discipline,secrets-routing}.md`)
- 3 project files (`memory/project_{nancy,<your-agent-project>,<your-project-1>}.md`)
- 5 deploy-tagged feedback files
- 4 deploy-tagged reference files

Phase B will retrofit the remaining ~75 memory files.

## Files in this repo

| Path | Purpose |
|---|---|
| `agents/memory-keeper.md` | Haiku agent owning Stage 1 + Stage 11 |
| `hooks/ship-phase-gate.sh` | Stage 9 gate (3-deploy rule, observability, smoke) |
| `scripts/validate-frontmatter.sh` | Validates v2 frontmatter (8 keys, type+severity vocab) |
| `scripts/test-ship-phase-gate.sh` | 11-fixture test suite for the hook |
| `scripts/register-ship-hook.py` | Idempotent registrar — adds hook entry to `~/.claude/settings.json` |
| `commands/ship.md` | Memory-aware /ship command (11 stages) |

## Bootstrap on a fresh Mac

`bin/bootstrap.sh` writes the baseline `~/.claude/settings.json` with the ship-phase-gate hook already registered (in PostToolUse → matcher `Agent|Bash`). On an existing Mac with a pre-v2 settings.json, run:

```bash
python3 ~/.claude/scripts/register-ship-hook.py
```

The script is idempotent — safe to re-run.

## Kill criterion

After 3 real `/ship` runs that exercise Stage 9, simplify back to bolt-on if any of:
- < 30% of loaded patterns surface anything actionable
- Zero new feedback files captured at Stage 11 across 3 runs
- Hook false-positive rate > 1 in 3 runs

See spec §12 for details.

## Phase B / C (deferred)

- **Phase B**: full 83-file frontmatter retrofit; per-agent `ship-stage` + `ship-patterns` frontmatter on existing 8 agents; hook gates on Stages 5 (Decision Lock) and 10 (Handoff)
- **Phase C**: hook gates on Stages 2 (Brainstorm), 4 (Explore), 7 (Test); `/build` and `/fix` integration; machine-readable JSON manifest
