# claude-config (public snapshot)

A mature, opinionated [Claude Code](https://claude.ai/code) setup published as a reference for power users. Snapshot from **2026-05-12**. Originally [Molly Shelestak](https://github.com/molly-diversifiedfun)'s working config, sanitized: brand voice, project memory, contact info, and session-specific files have been stripped.

> **This is not a beginner template.** It's a peer-to-peer share of a working power-user setup. Read the architecture, copy what makes sense for your workflow, leave the rest. Don't expect to clone-and-run on day one.

## What's inside

| Folder | What | Count |
|---|---|---|
| `agents/` | Custom subagents — specialist roles (PM, engineer, reviewer, debugger, security, etc.) | 14 |
| `commands/` | Slash commands (`/fix`, `/build`, `/ship`, `/write`, `/escalate-to`, `/plan`, etc.) | 18 |
| `skills/` | Custom skills (auto-invoked via the Skill tool when their description matches the prompt) | 36 |
| `rules/` | Coding / git / testing / security rules + CARL domain configs | 11 files |
| `hooks/` | Shell scripts wired into the Claude Code lifecycle (PreToolUse, PostToolUse, Stop, SessionStart, etc.) | 21 |
| `scripts/` | Runtime utilities (frontmatter validator, ship-phase-gate test harness, hook registrar) | 4 |
| `docs/` | Architecture, ship-pipeline-v2 spec, skills/agents/commands catalogs, install guide | 8+ |
| `CLAUDE.md` | Global instructions that auto-load every session | 1 |
| `bin/` | `install.sh`, `sync.sh`, `bootstrap.sh`, `sanitize-for-public.sh` | 4 |

**Not included** (intentionally):
- `settings.json` — has secrets and per-machine paths
- `projects/` — per-project memory (personal)
- `HANDOFF.md`, `TASKS.md`, `.ship/` — session-specific state
- `skills/brand-voice-router/` — was brand-specific; included as a *template stub* showing the pattern
- `rules/content-system/` — brand-specific content pipeline rules

## The interesting parts

**[`docs/ship-pipeline-v2.md`](docs/ship-pipeline-v2.md)** — A memory-aware 11-stage feature pipeline that loads tagged learnings into a `patterns.md` manifest at pre-flight, gates Stage 9 (Deploy + Smoke) with a hook enforcing the 3-deploy rule + observability + smoke-test sections, and captures new feedback at post-flight. Built to stop the same mistakes recurring.

**[`docs/architecture.md`](docs/architecture.md)** — How the pieces fit: skills vs agents vs commands vs hooks vs rules. The mental model.

**`hooks/`** — Lifecycle scripts that enforce discipline:
- `session-retrospective.sh` (Stop): 7-check Definition of Done — blocks session end if HANDOFF.md, TASKS.md, memory aren't updated.
- `block-dangerous.sh` (PreToolUse:Bash): regex-tightened to allow specific-path `rm -rf` while blocking catastrophic forms (root, home, glob).
- `observe-learning.sh` (Pre/PostToolUse): logs every tool invocation with skill name + subagent_type to `activity.jsonl` for usage telemetry.
- `agent-batch-validator.sh` (PreToolUse:Agent): enforces ≤4 explicit file path refs in agent prompts.
- `ship-phase-gate.sh` (PostToolUse:Agent|Bash): gates `/ship` Stage 9.
- `carl-loader.sh` (UserPromptSubmit): injects CARL domain rules (rule-system primer).

**`skills/learned/`** — 16 cross-project patterns synthesized from session feedback. Each has v2 frontmatter (`applies-to`, `projects`, `severity`, `phase`) so the ship-pipeline can filter-load them. Read `systematic-shortcutting.md`, `verify-before-commit.md`, and `deploy-iteration-discipline.md` first.

**The 14 agents** — Opinionated product team:
- `product-lead` (opus) → planning
- `engineer` (sonnet) → implementation
- `reviewer` (sonnet) → code review (read-only)
- `designer` (sonnet) → UI/UX
- `debugger` (opus) → bug investigation
- `tech-researcher` (sonnet) → API/library research
- `security` (opus) → audit (read-only)
- `project-manager` (haiku) → tracking + summaries
- `memory-keeper` (haiku) → owns ship-pipeline Stage 1 + Stage 11
- 4 `content-*` agents → content production lanes (architecture is reusable; brand-specifics were stripped)
- `market-researcher` → sales/market research + fact verification

## Quick start (cherry-pick, don't clone-and-run)

> **⚠️ If you already have a `~/.claude/` setup, back it up first.** `bin/install.sh` uses `rsync --delete` on `~/.claude/{skills,agents,commands,rules,hooks,scripts}` — files in those dirs that aren't in this repo will be removed. The script now prompts before overwriting, but a backup is the right insurance.
>
> ```sh
> cp -R ~/.claude ~/.claude.backup-$(date +%Y%m%d)
> ```

```sh
# 1. Clone somewhere safe (NOT directly to ~/.claude/)
git clone https://github.com/molly-diversifiedfun/claude-config-public ~/code/claude-config-public
cd ~/code/claude-config-public

# 2. Read the architecture before installing anything
$EDITOR docs/architecture.md docs/ship-pipeline-v2.md README.md

# 3a. Cherry-pick approach (recommended for existing power users):
#     copy individual hooks/skills/agents you want into your own ~/.claude/.
cp hooks/observe-learning.sh ~/.claude/hooks/   # example: just take the telemetry hook
cp -R skills/learned ~/.claude/skills/           # example: just take the learned/ patterns

# 3b. OR full install (recommended for fresh ~/.claude/):
$EDITOR bin/install.sh   # read it first
./bin/install.sh         # prompts before overwriting; use --yes to skip prompt
```

`bin/install.sh` will:
- **Sync (rsync --delete)** `agents/`, `commands/`, `rules/`, `hooks/`, `scripts/`, `skills/` into `~/.claude/` — overwriting existing content in those dirs
- **Copy** `CLAUDE.md` and (optional) `settings.local.json` to `~/.claude/`
- **Skip** `settings.json` (has secrets and per-machine paths), `projects/` (per-project memory)
- Leave `sessions/`, `cache/`, `telemetry/`, `backups/` alone

`bin/bootstrap.sh` is a heavier one-shot for a **fresh Mac** — it installs Claude Code, runs `install.sh`, writes a baseline `settings.json`, prompts for OAuth login, and bulk-installs plugins. Read it before running. macOS + Homebrew assumed.

After install, see [`CHECKLIST.md`](CHECKLIST.md) for the manual steps that can't be scripted (MCP server registration, plugin OAuth flows, API keys per skill).

## Customizing

Every reference to `<your brand>`, `<your-project-1>`, `<your nonfiction project>`, `<your signature project>`, `<your-content-brand>`, `<your-agent-project>`, `<your-personal-ai-project>`, etc., is a placeholder where personal content was stripped. Replace with your own.

The `learned/` patterns reference personal feedback file names (e.g. `feedback_session_<project>_learnings.md`). Those files don't exist in this repo (they were in the private memory dir) but the references are kept as breadcrumbs showing the source-of-truth pattern: cross-project learnings get distilled from session feedback into `learned/` over time.

## Conventions you'll need to understand

- **CARL** — A domain-rule injection system. See `hooks/carl-loader.sh` and `rules/common/`. The `*dev`, `*review`, `*brief` star-commands invoke specific rule domains.
- **Ship-pipeline v2** — `/ship` is memory-aware. Pre-flight loads tagged memory files. Stage 9 has a hook gate. Stage 11 captures new feedback. Full spec in `docs/ship-pipeline-v2.md`.
- **5-mode workflow** — `/fix` (quick), `/build` (standard), `/ship` (full pipeline), `/write` (content), `/escalate-to` (mode transition).
- **Live-first sync discipline** — `bin/sync.sh` is one-way (`~/.claude/` → repo). Edit live first, then sync. The original config's private memory documents the failure mode that drove this rule.

## What's NOT for the faint of heart

- Hooks enforce a strict DoD. Sessions are blocked from ending if HANDOFF.md / TASKS.md aren't updated. If you don't want that, comment out the `Stop` hook in `~/.claude/settings.json` after install.
- `block-dangerous.sh` blocks force-pushes, sudo, root-level `rm -rf`, and `curl | sh`. If you actually need to push --force, run it outside the session or edit the hook.
- `agent-batch-validator.sh` caps file path refs in Agent prompts at 4. Forces you to write "grep for X" instead of listing 10 files.
- The 16 `learned/` patterns are opinionated. Read them; disagree if you disagree; delete what doesn't fit you.

## License

MIT. Attribution appreciated but not required.

## Provenance

Snapshot from Molly Shelestak's working Claude Code config on 2026-05-12. Generated via `bin/sanitize-for-public.sh` from the private mirror. No commitment to ongoing sync — this is v1.0 and may be updated periodically or never.

The companion public skill marketplace lives at [claude-skills](https://github.com/molly-diversifiedfun/claude-skills).
