# Changelog

All notable changes to this snapshot will be documented here. This is a one-shot snapshot of a working personal config — there is no commitment to future versions, but if one ships, it lands here.

Format roughly follows [Keep a Changelog](https://keepachangelog.com). Versioning is calendar-based (`vYYYY.MM.DD`), not semantic — this isn't a library, it's a configuration mirror.

---

## [v1.1] — 2026-05-23

### Refresh — Phase 7.5 through Phase 8.1

Eleven days of work landed in the private config between v1.0 and this refresh. The big themes:

#### Skill catalog — make ~600 installed skills usable

- **`/skills "what you want to do"`** (Phase 7.2) — semantic search over the full skill catalog. Pre-filter by archetype + keyword grep, then top-5 with rationale. Iterated through 7.2.2 (description-line keyword match), 7.2.3 (stopwords + stemming calibration).
- **`/bake-off [--yolo|--control] "query"`** (Phase 7.3) — tournament-tests N skills on the same task. Three modes: blind3 (3 candidates A/B/C vote), yolo (1 untested skill self-rate), control (1 known-good vs 1 yolo). Rolling win/loss tallies at `data/bake-off-stats.tsv`.
- **`scripts/skills-prefilter.sh` Phase 7.4** — auto-elimination filter: skills with ≥3 appearances AND 0 wins drop from candidate lists. `untried` flag for skills with <3 appearances (✨ in display) to drive bake-off adoption.
- **`/consolidate-skills`** (Phase 7.7a → 7.7a.3) — static analysis to find duplicate skills. Composite score = description Jaccard (0.35) + body-token Jaccard (0.20) + bake-off shared losses (0.30) + elimination flag (0.15). Phase 7.7a.2 adds an LLM-judge layer (Haiku 4.5 via `claude --bare -p`) for the 0.15-0.30 ambiguity band — catches cross-vocab semantic overlap Jaccard misses.
- **`/merge-skills <pathA> <pathB>`** (Phase 7.7a.4) — Sonnet synthesizes a merged draft to `_drafts/`. Acceptance is manual (`mv` + `rm -rf` originals). Mocked-test isolation via `MERGE_DRAFTS_ROOT` env var.

#### Subagent discipline

- **Phase 7.5** — `hooks/inject-skills-for-agent.sh` (PreToolUse:Agent) prepends top-3 prefilter-matched skills into the subagent's prompt for 7 implementation lanes. Block wrapped in stable HTML-comment markers (7.5.1) so Phase 7.6 can detect injected dispatches.
- **Phase 7.6** — `hooks/agent-eval.sh` post-dispatch LLM-judge. `--enqueue` (PostToolUse:Agent) snapshots task + injected skills + return. `--drain` (Stop, after retrospective) processes the queue via Haiku 4.5, validates JSON with retry-once-on-bad-JSON, appends to `data/agent-eval.jsonl`. 20 files / 300s / 30s caps.

#### `/ship` Smart v3 (Phase 8.0) — scope-aware pipeline

- **Stage 0** — `scripts/ship-scope-classify.py` calls Haiku 4.5 to pick S / M / L / XL (30s timeout, soft-fails to S).
- Scope → stage matrix collapses small asks to minimal stages; explicitly binds [superpowers](https://github.com/obra/superpowers) skills (`tdd`, `verification-before-completion`, `brainstorming`, `requesting-code-review`, `finishing-a-development-branch`) per gate.
- Calibration follow-ups 8.0.1-8.0.7: aggregate floor for retro per-mode averages, mid-session DoD nudge, scope-classify continuation rule, scope inheritance from `.ship/<run>/scope.json`, pre-commit Stage 10 doc warning, scope-replay tool, ship-preflight dependency check.
- **Phase 8.1 (advisory)** — `hooks/ship-skill-tracker.sh` logs Skill invocations; `/ship-skill-status` reports which superpowers skills fired vs which were expected per scope. Advisory only — never blocks.

#### Retrospective + ops

- **`/system-retro`** (Phase 7.7c) — one-shot retrospective over last 20 sessions. Walks `~/.claude/projects/*/*.jsonl` with mtime + min-bytes filters. Per-session Haiku 4.5 judge scores 4 dimensions (shipped_and_smoked, incremental_value, mode_fit, time_to_done_vs_scope) + primary_gap + process_pattern label. Second synthesis judge surfaces cross-cutting themes. Forward-built slug index solves the lossy `.`-encoded cwd-slug reverse-parsing problem. Phase 7.7c.1 extends to scan `Skill` tool_use blocks (not just text-regex).
- **`/update-plugins`** (Phase 7.7b) — scans installed plugins, runs `git ls-remote origin HEAD` to detect upstream drift, prompts to update.

#### Counts

- **37 skills** (`skills/`, up from 36) — see [`docs/skills.md`](docs/skills.md).
- **14 agents** (`agents/`) — unchanged.
- **32 hooks** (`hooks/`, up from 21) — new: archetype-injector, inject-skills-for-agent, agent-eval, mempalace-wrapper, mid-session-dod-nudge, ship-skill-tracker, surface-hook-blocks, synthesize-learnings, workflow-gate, validate-n8n-workflow, auto-push-after-commit.
- **27 slash commands** (`commands/`, up from 18) — new: bake-off, consolidate-skills, merge-skills, ship-preflight, ship-scope-replay, ship-skill-status, skills, system-retro, update-plugins.
- **21 scripts** (`scripts/`, up from 4) — new: bake-off-{lib,prefilter,record}, bootstrap-skill-archetypes.py, consolidate-skills.py, merge-skills.py, record-audience.sh, ship-preflight.py, ship-scope-classify.py, ship-scope-replay.py, ship-skill-status.py, skills-prefilter.sh, system-retro.py, update-plugins.py, validate-skill-archetypes.sh, validate-work-type-chains.sh.
- **12 CARL domains** (`carl/`, NEW) — domain configs auto-loaded by `carl-loader.sh` on UserPromptSubmit (`global`, `context`, `workflow`, `rigor`, `commands`, `scope`, `design`, `memory`, `manifest`, `n8n`, plus `content-rules` + `writing` which are excluded from this public snapshot).
- **3 root yaml configs** (`projects.yaml`, `skill-archetypes.yaml`, `work-type-chains.yaml`) — drive archetype injection + skill prefiltering.

### Sanitization
Same script-driven approach as v1.0. New brand/project slugs added to the sed pass:
`<your-first-brand>` / `<your-second-brand>` / `<your-third-brand>` / `<your-bot>` / `<your-orchestrator>` / `<your-web-app-N>` / `<your-bot-N>` / `<your-content-pipeline>` / `<your-product-pipeline>` / etc.

Excluded from this snapshot:
- `skills/brand-voice-router/` (template stub instead)
- `skills/ai-build-partner/` (shipped separately in `claude-skills` public repo)
- `skills/learned/qa-rules.md`, `research-budgets.md`, `competitive-history.md`, `hook-performance.md` (personally-dense)
- `docs/specs/`, `docs/plans/`, `docs/site/` (in-flight work)
- `commands/unstuck.md`, `commands/canva-carousel.md`, `commands/sync-notion.md` (brand-specific)
- `rules/content-system/` (brand-specific)
- `carl/content-rules`, `carl/writing`, `carl/n8n`, `carl/manifest` (brand-specific + contain private infra references)

---

## [v1.0] — 2026-05-12

### Initial public snapshot

- **36 skills** (`skills/`) — custom skills auto-invoked via the Skill tool. Includes 16 `learned/` cross-project patterns with v2 frontmatter for the memory-aware `/ship` pipeline.
- **14 agents** (`agents/`) — `product-lead`, `engineer`, `reviewer`, `designer`, `debugger`, `tech-researcher`, `security`, `project-manager`, `memory-keeper`, 4 `content-*` lanes, `market-researcher`.
- **21 hooks** (`hooks/`) — lifecycle scripts including `session-retrospective.sh` (Stop, 7-check DoD), `block-dangerous.sh` (PreToolUse:Bash, 11/11 test cases), `observe-learning.sh` (telemetry), `ship-phase-gate.sh` (gates `/ship` Stage 9).
- **18 slash commands** (`commands/`) — `/fix`, `/build`, `/ship`, `/write`, `/plan`, `/handoff`, `/escalate-to`, etc.
- **11 rule files** (`rules/`) — common conventions + CARL domain configs.
- **8 docs files** (`docs/`) — architecture, ship-pipeline-v2 spec, install guide, skills/agents/commands/hooks catalogs.
- **4 bin scripts** (`bin/`) — `install.sh`, `sync.sh`, `bootstrap.sh`, `sanitize-for-public.sh`.

### Sanitization
Generated from a private working config via `bin/sanitize-for-public.sh`. Zero personal handles, zero personal project names, zero hardcoded paths. `brand-voice-router/` shipped as a template stub. `rules/<your-content-pipeline>/` excluded entirely.

### Visual artifacts
- 11-stage `/ship` pipeline Mermaid diagram (renders natively on GitHub).
- 1200×630 OG social card at `assets/og-card.png` — uploaded as the repo's social preview.

### Audience
Power users + Claude Code builders. Not beginners. Read `docs/architecture.md` and `docs/ship-pipeline-v2.md` before installing.

### Followability score (self-assessed, post-redesign)
UNDERSTAND 5 / BELIEVE 5 / DO 5 / REPEAT 3 / SHARE 4 — avg 4.4.

---

## Future versions

If v1.1 ships, expect:
- Updated counts as the private config drifts
- New `learned/` patterns from intervening sessions
- Hook tightening based on real failures

No timeline. Watch the repo or check back; either is fine.
