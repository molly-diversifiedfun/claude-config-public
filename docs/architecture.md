# Architecture — How the Pieces Fit

Claude Code's extensibility surface has six distinct extension points. They look similar from a distance but compose differently.

```
              ┌─────────────────────────────────────────────────┐
              │                  CLAUDE.md                       │
              │  Global instructions, auto-loaded every session │
              │  Sets persona, communication style, preferences │
              └────────────────────────┬─────────────────────────┘
                                        │
   ┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
   ▼          ▼          ▼          ▼          ▼          ▼          ▼
┌──────┐  ┌──────┐  ┌────────┐ ┌──────┐  ┌────────┐ ┌──────┐  ┌──────┐
│Skills│  │Agents│  │Commands│ │Rules │  │Learned │ │Hooks │  │Scripts│
└──────┘  └──────┘  └────────┘ └──────┘  │Patterns│ └──────┘  └──────┘
auto-     user-     user-      always-on  └────────┘ auto-     standalone
invoked   invoked   invoked    static     archetype-  fired     CLIs called
on desc   via Task  via /name  context    filtered   on        by hooks +
match                                     dynamic    lifecycle commands
                                          context    events
```

## Skills (`skills/`, ~44 total)

**Purpose:** Specialized capabilities Claude invokes *automatically* when the user's request matches the skill's `description` field.

**Activation:** The Skill tool. Each skill has a YAML frontmatter `description` that lists trigger phrases. When the user's message matches, Claude calls `Skill(name)` and the skill's content loads into context.

**Examples:**
- `humanize-ai-writing` — fires when user says "make this sound human" / "remove AI tells"
- `brand-voice-router` — fires when user requests any branded content
- `decision-maker` — fires when user is choosing between 2-4 options

**When to add one:** When you find yourself re-typing the same instructions across sessions. Pull them into a SKILL.md with a precise description so future-you doesn't have to remember.

See: [docs/skills.md](skills.md) for the full catalog.

## Agents (`agents/`, 12 total)

**Purpose:** Specialized subagent roles invokable via the `Task` tool. Each runs in its own context window, has its own model + tool palette, and produces a focused output back to the parent.

**Activation:** Explicit. Either via a slash command (`/build` invokes `builder`, `/plan` invokes `product-lead`, `/decide` invokes `strategist`) or manually via Task tool with `subagent_type=builder`.

**Examples:**
- `builder` (Sonnet) — implements approved specs with TDD
- `debugger` (Opus) — investigates gnarly bugs, root-cause analysis
- `reviewer` (Sonnet) — pre-merge code review, read-only

**When to add one:** When work has a distinct *role* with its own quality bar — different model needs, different tool restrictions, different output shape from the main thread. Don't make an agent for a one-off task; that's what skills are for.

See: [docs/agents.md](agents.md) for the team roster.

## Commands (`commands/`, ~33 total)

**Purpose:** User-typed entry points (`/build`, `/ship`, `/handoff`). Each command is a markdown file whose body becomes the prompt when typed.

**Activation:** User types `/<name>` in chat.

**Examples:**
- `/build` — standard feature mode (lightweight spec, 3-5 agents, auto-proceed)
- `/ship` — Smart v3 (Phase 8.0). Stage 0 calls Haiku to pick S/M/L/XL scope; only stages that fit run.
- `/decide` — routes to strategist agent for structured decision-making
- `/skills`, `/bake-off`, `/consolidate-skills` — skill catalog management
- `/system-retro` — retrospective over recent sessions

**When to add one:** When a workflow has 3+ predictable steps and you want a one-token entry point.

See: [docs/commands.md](commands.md) for the reference.

## Rules (`rules/`, 13 files in 4 domains)

**Purpose:** Static always-on coding/git/testing/security conventions. Always loaded.

**Activation:** Listed in `CLAUDE.md` and loaded as part of the session preamble.

**Domains:**
- `common/` — universal (coding-style, git-workflow, testing, security, agents, performance, patterns, definition-of-done)
- `content-system/` — content production rules (caption-generation, content-plan-enforcement)
- `python/` — Python style
- `typescript/` — TypeScript style + patterns

**When to add one:** When the rule should hold across most/all sessions in a domain.

See: [docs/rules.md](rules.md) for the rule system.

## Learned Patterns (`skills/learned/`, ~44 files)

**Purpose:** Cross-project corrections and discipline rules, synthesized from session feedback. The dynamic counterpart to static `rules/`. Each pattern has YAML frontmatter with `severity` and `archetypes` fields that control when it loads.

**Activation:** `hooks/archetype-injector.sh` (UserPromptSubmit). Resolves the cwd to a project archetype, then injects:
- All `severity: blocking` patterns (5 patterns, always-on regardless of archetype)
- Archetype-matched `severity: warning` patterns (filtered by the `archetypes:` field)

**Severity levels:**
- `blocking` (5 patterns) — always-on: `never-fabricate`, `secrets-routing`, `auto-mode-classifier-discipline`, `verify-before-commit`, `cli-integration-discipline`
- `warning` (~39 patterns) — loaded when archetype matches (e.g., `n8n-build-patterns` only loads for `telegram-bot` and `infra-config` archetypes)

**When to add one:** When a correction or discipline has been learned the hard way and should prevent the same mistake across future sessions. Use `/promote` to turn a session feedback file into a learned pattern.

**History:** Previously, a separate system called CARL (Context Augmentation & Reinforcement Layer) handled dynamic rule injection via 11 domain files with 130 rules. In the 2026-05-26 simplification, ~110 rules were found to duplicate existing learned patterns, and ~25 unique rules were migrated to 7 new learned patterns. CARL now only handles star-commands (`*dev`, `*review`, `*brief`).

## Star-Commands (`carl/commands`)

**Purpose:** Mode-switching shortcuts (`*dev`, `*review`, `*brief`, `*plan`, `*discuss`, `*debug`, `*explain`). Each sets behavioral rules for the current interaction style.

**Activation:** `hooks/carl-loader.sh` (UserPromptSubmit). Detects `*word` pattern in the prompt, loads matching rules from `carl/commands`.

**When to use:** Type `*brief` for bullet-point-only mode, `*dev` for code-first mode, `*review` for code review mode.

## Hooks (`hooks/`, ~24 scripts)

**Purpose:** Shell scripts wired into Claude Code's lifecycle events. They run *automatically* on `PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`, etc., and can validate, transform, log, or block.

**Activation:** Configured in `settings.json` under the relevant lifecycle event. Each hook receives a JSON payload over stdin.

**Examples:**
- `archetype-injector.sh` (UserPromptSubmit) — resolves cwd → archetype, injects relevant learned patterns
- `block-dangerous.sh` (PreToolUse:Bash) — blocks destructive commands (rm -rf, force-push, curl|sh)
- `session-retrospective.sh` (Stop) — DoD enforcement with grace (1st miss = nudge, 2nd+ = block)
- `caption-guard-unified.sh` (PreToolUse:Bash+Write|Edit) — enforces caption pipeline
- `mempalace-wrapper.sh` (Stop/PreCompact/SessionStart) — long-tail memory auto-save + wake-up

**Kill switches:** Every hook has an env var that disables it. Full reference at `hooks/KILL_SWITCHES.md`.

**When to add one:** When the behavior must run *every time* a lifecycle event fires, regardless of whether Claude "remembers" to. Hooks are the only mechanism that's truly automatic.

See: [docs/hooks.md](hooks.md) for the full hook reference.

## Scripts (`scripts/`, ~21 utilities)

**Purpose:** Standalone Python/Bash utilities called by hooks, commands, or directly by the user.

**Categories:**
- **Catalog management** — `skills-prefilter.sh`, `consolidate-skills.py`, `merge-skills.py`, `bake-off-prefilter.sh`, `bake-off-record.sh`
- **Ship pipeline** — `ship-scope-classify.py` (Haiku S/M/L/XL), `ship-scope-replay.py`, `ship-skill-status.py`, `ship-preflight.py`
- **Observability** — `system-retro.py` (Haiku retrospective judge)
- **Validation** — `validate-frontmatter.sh`, `validate-manifest.sh`, `validate-skill-archetypes.sh`, `validate-work-type-chains.sh`
- **Manifest** — `render-manifest.py`, `classify-scope.sh`
- **MemPalace** — `mempalace-bulk-load.sh`

## How they compose — a worked example

User says: *"write me an Instagram caption about ship-it culture"*

1. **Hook** (`archetype-injector.sh`) fires on UserPromptSubmit → resolves archetype, injects relevant learned patterns (including `ai-tell-avoidance`, `present-labeled-options`)
2. **Rule** (auto-loaded content rules) — Claude now knows: max 1 tool mention, no PM jargon, @your-handle handle, no AI-tell numbers like 47.
3. **Skill** (`brand-voice-router`) auto-invokes because "Instagram caption" matches its trigger → routes to <your brand> voice.
4. **Skill** (`humanize-ai-writing`) auto-invokes after draft → strips AI patterns.
5. **Skill** (`hooks` skill, not the lifecycle hook!) auto-invokes for the opener → 5 hook variants.
6. **Hook** (`content-qa-guarded.sh`) fires on PostToolUse:Write → validates the saved draft.
7. **Hook** (`session-retrospective.sh`) fires on Stop → checks HANDOFF.md + TASKS.md freshness (grace mechanism: nudge on 1st miss, block on 2nd+).

For implementation work, the picture inverts: user types `/build`, which invokes the `builder` agent, which uses skills and rules during its work, with hooks firing throughout.

## Source-of-truth model

This repo is the source of truth for `~/.claude/{skills,agents,commands,rules,hooks,scripts,CLAUDE.md}` PLUS `~/.carl/` → `repo/carl/`. The flow:

```
Primary Mac (where you edit live)
    ~/.claude/skills/foo edited      ~/.carl/commands edited
    │                                │
    └────────────┬───────────────────┘
                 │
    bin/sync.sh: pulls into the repo
    │
    └─→ git commit + push
            │
            └─→ Mac mini (or any other machine)
                    git pull
                    │
                    └─→ bin/install.sh: writes repo content back to ~/.claude/* + ~/.carl/*
```

`settings.json` is **never** in this repo (has secrets). `projects/`, `sessions/`, `cache/`, `backups/`, `telemetry/` are also excluded — that's runtime state, not config.

## Public mirror

A sanitized snapshot lives at [`<your-github-username>/claude-config-public`](https://github.com/<your-github-username>/claude-config-public). Generated via `bin/sanitize-for-public.sh` + a manual cleanup pass.
