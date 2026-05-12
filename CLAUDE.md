# Claude Code Configuration

## Product Team — ALWAYS Delegate

You have 14 specialized agents. **USE THEM.** Don't do everything yourself.

| Agent | Model | Role | Key Skills/Plugins |
|-------|-------|------|--------------------|
| product-lead | opus | PM/Tech Lead | ask-questions-if-underspecified, compound-engineering, brainstorm, mental-models, devils-advocate |
| engineer | sonnet | Implementation | compound-engineering, superpowers (TDD/debug/verify), everything-claude-code (postgres/api/security), firecrawl, context7 |
| reviewer | sonnet | Code Review (read-only) | code-review, pr-review-toolkit, differential-review, code-simplifier |
| designer | sonnet | UI/UX Design | frontend-design, ui-ux-pro-max, nano-banana, playwright |
| debugger | opus | Bug Investigation | superpowers (systematic-debugging, verification) |
| tech-researcher | sonnet | API/library/doc research | firecrawl, context7, WebSearch |
| security | opus | Security Audit (read-only) | audit-context-building, everything-claude-code (security-review/scan) |
| project-manager | haiku | Tracking/Summaries (read-only) | handoff, code-documenter |
| memory-keeper | haiku | Owns /ship Stage 1 (pre-flight pattern load) + Stage 11 (capture) | (frontmatter-tagged memory glob; see ship pipeline v2) |
| content-social | sonnet | Short-form social (IG/LI/TT/Reels) | brand-voice-router, humanize-ai-writing, repurpose, hooks, carousel-writer, video-script |
| content-longform | sonnet | Books, ebooks, blogs, workbooks, brand PDFs | brand-voice-router, non-fiction-book-factory, ebook-factory, doc-coauthoring, ship-it-brand-pdf |
| content-business | sonnet | Proposals, decks, sales emails (drafts only) | proposal-builder, product-packaging-pricing, sales-call-debrief, talk-track-generator, theme-factory |
| content-qa | haiku | Content QA (read-only, checklist) | learned/qa-rules.md, scripts/qa/* |
| market-researcher | sonnet | Sales/marketing/product research, fact verification | firecrawl, Apify, Notion research DB |

See `rules/common/agents.md` for slash commands and orchestration rules.

## 5 Modes — How Work Flows

| Mode | Command | When |
|------|---------|------|
| Quick Fix | `/fix` | Bugs, small changes, no spec needed |
| Standard Build | `/build` | Features, 30-min lightweight spec |
| Full Pipeline | `/ship` | Major features, full spec, security audit. **Memory-aware v2** (vertical slice for Stage 9 Deploy + Smoke). Pre-flight loads tagged patterns; Stage 11 captures new feedback. See `docs/ship-pipeline-v2.md`. |
| Content | `/write` | Copy, docs, book chapters, brand content |
| Escalate | `/escalate-to` | Mode transition when scope grows |

**Phase gating:** Auto-proceed unless agent reports DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED.

## CARL Rule System

CARL auto-injects domain rules via `carl-loader.sh` on every UserPromptSubmit.
- **GLOBAL + CONTEXT** always on. **COMMANDS** via star-commands (`*dev`, `*review`, `*brief`).
- **RIGOR** triggers on: settings.json, config, schema, manifest, hooks, tsconfig, CLAUDE.md, plugins, MCP.
- Domains: GLOBAL, CONTEXT, WORKFLOW, RIGOR, COMMANDS, WRITING. (The original private config also carried CONTENT-RULES domain; stripped from this public snapshot.)
- Use `carl-manager` skill to create/edit. Use `carl-help` for reference.

## Skill Collections

Custom skills (in `~/.claude/skills/`):
- **Learned patterns:** `learned/` — 16 cross-project pattern files synthesized from feedback (all carry v2 frontmatter)
- **Brand voice:** `brand-voice-router/` — template stub in this public snapshot (was originally brand-specific). Replace with your own brand routing.
- **Writing:** `humanize-ai-writing/`, `voice-extractor/`
- **Thinking:** `mental-models/`, `devils-advocate/`, `decision-maker/`, `self-interview/`, `ask-me-the-questions/`
- **Content:** `brainstorm/`, `code-documenter/`, `handoff/`
- **Dev tools:** `carl-manager/`, `carl-help/`, `nano-banana/`, `firecrawl/`

External (not auto-discovered):
- Writing books: `~/github/claude-code-toolkit/skills/non-fiction-book-factory/`
- Writing ebooks: `~/github/claude-code-toolkit/skills/ebook-factory/`
- Writing craft: `~/github/claude-code-toolkit/skills/writing/`

## Hooks (enforced automatically)

| Hook | Event | What it does |
|------|-------|-------------|
| session-retrospective.sh | Stop | **7-check DoD enforcement** — blocks exit if incomplete |
| carl-loader.sh | UserPromptSubmit | Injects CARL domain rules |
| observe-learning.sh | Pre/PostToolUse | Logs activity, increments counter, rotates at 5MB |
| synthesize-learnings.sh | SessionStart | Flags unprocessed feedback for learned/ synthesis |
| check-model-freshness.sh | SessionStart | Warns if model refs >90 days stale |
| content-qa-guarded.sh | PostToolUse:Write\|Edit | PM jargon, tool mentions, 47, handle (content files only) |
| agent-batch-validator.sh | PreToolUse:Agent | Enforces ≤4 file path refs in agent prompts |
| ship-phase-gate.sh | PostToolUse:Agent\|Bash | Gates /ship Stage 9 (Deploy + Smoke). 3-deploy rule, observability check, smoke check. Activates only when `.ship/<run>/patterns.md` is present. |

## Plugins (enabled in settings.json)

**Core:** superpowers, commit-commands, context7, typescript-lsp, playwright, supabase
**Engineering:** compound-engineering, code-review, pr-review-toolkit, code-simplifier, everything-claude-code
**Security:** audit-context-building (trailofbits), differential-review (trailofbits), ask-questions-if-underspecified (trailofbits)
**Design:** frontend-design, ui-ux-pro-max

## MCP Integrations

Connected (read auto-approved, writes need confirmation):
Gmail, Google Calendar, Notion, Canva, Playwright, Context7, Firecrawl.

## Memory System

Persistent at `~/.claude/projects/<your-workspace-path>/memory/`:
- `MEMORY.md` — index (loaded every session)
- Individual files by type: user, feedback, project, reference
- Feedback files auto-checked against `learned/` by synthesize-learnings.sh
- **v2 frontmatter schema** (added 2026-05-10) on `learned/` + `memory/` files: `name`, `description`, `type`, `applies-to: [tags]`, `projects: [names|all]`, `severity: blocking|warning|info`, `phase: [stages]`, `last-validated`. Validated by `~/.claude/scripts/validate-frontmatter.sh`.
- **memory-keeper agent** loads filtered set into `.ship/<run>/patterns.md` at /ship pre-flight; captures new feedback at post-flight.
- See `docs/ship-pipeline-v2.md` for the full pipeline + tag vocabulary.

# Your Preferences (customize this section)

The original config carried personal preferences for communication style, writing voice, language choices, etc. They were stripped from this public snapshot — replace with your own. Below are the **non-personal** discipline rules that the rest of this config depends on. Keep these or they'll silently misfire.

## Context Management — CRITICAL
- At **70% context**, STOP and do IN ORDER:
  1. Finish and commit in-progress code changes
  2. Push to remote
  3. Update HANDOFF.md (goal, done, not done, decisions, resume instructions)
  4. Update TASKS.md (mark complete, add discovered work)
  5. `/compact Focus on [specific area]`
- After compaction, re-read HANDOFF.md and the active spec.
- NEVER compact without this checklist.

## Config Safety
- Before editing ANY settings file, ALWAYS read it first.
- Before editing CLAUDE.md, read it first. Never blindly append.

## Progress Tracking
- DoD enforced by session-retrospective.sh (7 checks, blocks session end).
- See `rules/common/definition-of-done.md` for full checklist + doc mapping.
- "Major milestone" = committed feature, architectural decision, or resolved bug a future session needs.
