# Architecture — How the Pieces Fit

Claude Code's extensibility surface has five distinct extension points. They look similar from a distance but compose differently.

```
              ┌─────────────────────────────────────────────────┐
              │                  CLAUDE.md                       │
              │  Global instructions, auto-loaded every session │
              │  Sets persona, communication style, preferences │
              └────────────────────────┬─────────────────────────┘
                                        │
   ┌─────────────────┬──────────────────┼──────────────────┬──────────────────┐
   ▼                 ▼                  ▼                  ▼                  ▼
┌────────┐      ┌────────┐         ┌────────┐         ┌────────┐         ┌────────┐
│ Skills │      │ Agents │         │Commands│         │ Rules  │         │ Hooks  │
└────────┘      └────────┘         └────────┘         └────────┘         └────────┘
auto-invoked   user-invoked       user-invoked       auto-injected      auto-fired
when desc      via Task tool      via "/name"        when triggers      on lifecycle
matches user                                          hit                events
intent
```

## Skills (`skills/`, 36 total)

**Purpose:** Specialized capabilities Claude invokes *automatically* when the user's request matches the skill's `description` field.

**Activation:** The Skill tool. Each skill has a YAML frontmatter `description` that lists trigger phrases. When the user's message matches, Claude calls `Skill(name)` and the skill's content loads into context.

**Examples:**
- `humanize-ai-writing` — fires when user says "make this sound human" / "remove AI tells"
- `brand-voice-router` — fires when user requests any branded content
- `decision-maker` — fires when user is choosing between 2-4 options

**When to add one:** When you find yourself re-typing the same instructions across sessions. Pull them into a SKILL.md with a precise description so future-you doesn't have to remember.

See: [docs/skills.md](skills.md) for the full catalog.

## Agents (`agents/`, 14 total)

**Purpose:** Specialized subagent roles invokable via the `Task` tool. Each runs in its own context window, has its own model + tool palette, and produces a focused output back to the parent.

**Activation:** Explicit. Either via a slash command (`/build` invokes `engineer`, `/plan` invokes `product-lead`) or manually via Task tool with `subagent_type=engineer`.

**Examples:**
- `engineer` (Sonnet) — implements approved specs with TDD
- `debugger` (Opus) — investigates gnarly bugs, root-cause analysis
- `reviewer` (Sonnet) — pre-merge code review, read-only

**When to add one:** When work has a distinct *role* with its own quality bar — different model needs, different tool restrictions, different output shape from the main thread. Don't make an agent for a one-off task; that's what skills are for.

See: [docs/agents.md](agents.md) for the team roster.

## Commands (`commands/`, 20 total)

**Purpose:** User-typed entry points (`/build`, `/ship`, `/handoff`). Each command is a markdown file whose body becomes the prompt when typed.

**Activation:** User types `/<name>` in chat.

**Examples:**
- `/build` — standard feature mode (lightweight spec → 3-5 agents → auto-proceed)
- `/ship` — full pipeline mode, memory-aware v2 (11 stages: pre-flight + 9 agents + capture; Stage 9 hook-gated). See `docs/ship-pipeline-v2.md`.
- `/handoff` — generate a session-continuity doc

**When to add one:** When a workflow has 3+ predictable steps and you want a one-token entry point. Commands are sugar over "type the same paragraph every time you want to do X."

See: [docs/commands.md](commands.md) for the reference.

## Rules (`rules/`, 13 files in 4 domains)

**Purpose:** Always-on context that gets injected into every session. Coding conventions, content voice, brand constraints, testing requirements, etc.

**Activation:** Auto-injected via the **CARL** rule loader (a hook at `UserPromptSubmit`). CARL loads `rules/common/*.md` always; domain-specific rules load when triggers in the user's message match.

**Domains:**
- `common/` — universal (coding-style, git-workflow, testing, security, agents, performance, patterns)
- `content-system/` — content production rules (caption-generation, content-plan-enforcement)
- `python/` — Python style
- `typescript/` — TypeScript style

**When to add one:** When the rule should hold across most/all sessions in a domain. Don't put rules in skills (which only fire on match); rules are for things that need to be top-of-mind always.

See: [docs/rules.md](rules.md) for the rule system.

## Hooks (`hooks/`, 21 scripts)

**Purpose:** Shell scripts wired into Claude Code's lifecycle events. They run *automatically* on `PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`, etc., and can validate, transform, log, or block.

**Activation:** Configured in `settings.json` under the relevant lifecycle event. Each hook receives a JSON payload over stdin.

**Examples:**
- `carl-loader.sh` (UserPromptSubmit) — injects matching rule files into context
- `agent-batch-validator.sh` (PreToolUse:Agent) — enforces ≤4 file path refs in agent prompts
- `session-retrospective.sh` (Stop) — 7-check Definition-of-Done enforcement
- `content-qa-guarded.sh` (PostToolUse:Write|Edit) — checks PM jargon, banned numbers, handle correctness

**When to add one:** When the behavior must run *every time* a lifecycle event fires, regardless of whether Claude "remembers" to. Hooks are the only mechanism that's truly automatic — skills/agents/commands all require Claude to invoke them.

See: [docs/hooks.md](hooks.md) for the hook reference.

## How they compose — a worked example

User says: *"write me an Instagram caption about ship-it culture"*

1. **Hook** (`carl-loader.sh`) fires on UserPromptSubmit → injects `rules/common/coding-style.md`, `rules/content-system/caption-generation-enforcement.md`, brand voice rules.
2. **Rule** (auto-loaded content rules) — Claude now knows: max 1 tool mention, no PM jargon, @your-handle handle, no AI-tell numbers like 47.
3. **Skill** (`brand-voice-router`) auto-invokes because "Instagram caption" matches its trigger description → routes to <your brand> voice.
4. **Skill** (`humanize-ai-writing`) auto-invokes after draft → strips AI patterns.
5. **Skill** (`hooks` skill, not the lifecycle hook!) auto-invokes for the opener → 5 hook variants.
6. **Hook** (`content-qa-guarded.sh`) fires on PostToolUse:Write → validates the saved draft against learned/qa-rules.md.
7. **Hook** (`session-retrospective.sh`) fires on Stop → enforces DoD checklist before session ends.

No slash command, no agent — just skills and rules and hooks composing.

For implementation work, the picture inverts: user types `/build`, which invokes the `engineer` agent, which uses skills and rules during its work, with hooks firing throughout.

## Source-of-truth model

This repo is the source of truth for `~/.claude/{skills,agents,commands,rules,hooks,CLAUDE.md,settings.local.json}`. The flow:

```
Primary Mac (where you edit live)
    ~/.claude/skills/foo edited
    │
    ├─→ bin/sync.sh: pulls ~/.claude/* into the repo (sanitizes paths)
    │
    └─→ git commit + push
            │
            └─→ Mac mini (or any other machine)
                    git pull
                    │
                    └─→ bin/install.sh: pushes repo content into ~/.claude/*
```

`settings.json` is **never** in this repo (has secrets). `projects/`, `sessions/`, `cache/`, `backups/`, `telemetry/` are also excluded — that's runtime state, not config.
