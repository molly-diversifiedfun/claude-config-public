# Rules System

The repo has TWO complementary rule mechanisms:

1. **`rules/`** — static markdown rules referenced from `CLAUDE.md`. Loaded every session as part of the preamble. Universal coding/git/testing/security conventions.
2. **`skills/learned/`** — dynamic archetype-filtered patterns. Loaded by `hooks/archetype-injector.sh` (UserPromptSubmit) based on project archetype + severity.

**Historical note:** A third mechanism called CARL (Context Augmentation & Reinforcement Layer) previously provided 11 domains with 130 keyword-triggered rules. In the 2026-05-26 simplification, ~110 rules were found redundant with learned patterns, and ~25 unique rules were migrated. CARL now only handles **star-commands** (`*dev`, `*review`, `*brief`).

## `rules/` — static domains

| Domain | What | Always-on? |
|---|---|---|
| `common/` | Universal rules — coding-style, git-workflow, testing, security, agents, performance, patterns, definition-of-done | Yes |
| `content-system/` | Content production rules — caption-generation-enforcement, content-plan-enforcement | When content commands/skills fire |
| `python/` | Python-specific style rules | When user is working in Python |
| `typescript/` | TypeScript-specific style rules + patterns | When user is working in TS |

## `skills/learned/` — dynamic learned patterns (~44 files)

Each pattern has YAML frontmatter:

```yaml
---
name: pattern-name
description: one-line summary
severity: blocking | warning
archetypes: [web-app, telegram-bot, always-on, ...]
last-validated: 2026-05-26
---
```

**How they load:** `archetype-injector.sh` resolves cwd → project archetype (from `projects.yaml`), then:
- All `severity: blocking` patterns load unconditionally (5 patterns)
- `severity: warning` patterns load only when their `archetypes` field includes the current project's archetype

**Blocking patterns (5, always-on):**
- `never-fabricate` — don't invent stories, numbers, or biographical details
- `secrets-routing` — secrets go direct to deploy targets, never through chat
- `auto-mode-classifier-discipline` — don't retry denied tool calls in loops
- `verify-before-commit` — read agent output before staging; smoke after deploy
- `cli-integration-discipline` — measure cost/latency before wrapping external CLIs

**Warning patterns (~39, archetype-filtered) — examples:**
- `ai-tell-avoidance` — never use 47, vary numbers, no AI filler phrases (brand-content, web-app)
- `n8n-build-patterns` — no fetch() in Code nodes, mock UX first (telegram-bot, infra-config)
- `design-color-discipline` — Unstuck brand colors + typography (web-app, brand-content)
- `context-brackets` — adapt behavior for FRESH/MODERATE/DEPLETED context (always-on)
- `check-before-create` — ls target dir before creating new files (always-on)

## Star-commands

Star-commands set behavioral modes. Type `*word` anywhere in your prompt:

| Command | What it does |
|---|---|
| `*dev` | Code-first mode: show code, minimize explanation, run tests |
| `*review` | Code review mode: flag security, note performance, respect existing style |
| `*brief` | Bullet points only, max 5 items, skip explanations |
| `*plan` | Planning mode: explore codebase, present options with tradeoffs, get approval |
| `*discuss` | Brainstorm mode: explore approaches, ask clarifying questions |
| `*debug` | Debug mode: gather error context, form hypothesis, test systematically |
| `*explain` | Teaching mode: high-level overview first, concrete examples, build incrementally |

Star-commands are loaded by `hooks/carl-loader.sh` from `carl/commands`.

## What's in `common/`

| File | What |
|---|---|
| `coding-style.md` | Immutability, file organization (200-400 lines, 800 max), error handling, input validation |
| `git-workflow.md` | Conventional Commits, PR workflow, feature implementation order |
| `testing.md` | 80% coverage, TDD workflow, behavioral specs, registry contract testing, production smoke |
| `security.md` | Mandatory security checks, secret management, response protocol |
| `agents.md` | Agent roster, slash commands, parallel execution, hooks system |
| `performance.md` | Model selection (Haiku/Sonnet/Opus), context management, extended thinking |
| `patterns.md` | Skeleton projects, repository pattern, API response envelope |
| `definition-of-done.md` | DoD checklist — code, verification, docs, tracking, decisions, deploy |

## Why this design

- **Rules** are *passive* and *always-on* (within their domain). They shape the model's behavior baseline.
- **Learned patterns** are *passive* and *archetype-filtered*. They inject relevant corrections based on what project you're in.
- **Skills** are *active* and *trigger-based*. They add capabilities when the user's request matches.
- **Hooks** are *imperative* and *lifecycle-bound*. They execute scripts at specific events.

Use rules for things you want the model to *know* always. Use learned patterns for project-specific corrections. Use skills for things you want the model to *do* when matched. Use hooks for things you want to happen *every time* a lifecycle event fires.
