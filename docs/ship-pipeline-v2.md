# Ship Pipeline v2 — Memory-Aware /ship

**Status:** v1 vertical slice shipped 2026-05-10. Stage 9 (Deploy + Smoke) gated end-to-end. Stages 1 + 11 (pre-flight + capture) wired. Stages 2–8 + 10 stay as inline reminders for v1; Phase B/C will gate them.

> The original spec + 22-task implementation plan are NOT in this public snapshot (they were excluded along with `docs/specs/` and `docs/plans/`). This doc is the standalone overview. The full design narrative lives in the [companion case study](https://github.com/molly-diversifiedfun/claude-skills) if/when it's published there.

## What changed

`/ship` used to be a 12-line orchestration script that called 9 agents in order with no awareness of the 83 memory files or 19 distilled `learned/` patterns it lived alongside. Same mistakes recurred: silent failures committed, scope narrowed, fabrications, blind 4th-deploy iterations.

v2 makes `/ship` memory-aware end-to-end:

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
- 3 project files (`memory/project_{<your-personal-ai-project>,<your-agent-project>,<your-project-1>}.md`)
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
