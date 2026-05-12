# Rules System (CARL)

Rules are always-on context that gets injected into every session. They cover coding conventions, content voice, brand constraints, testing requirements, security guidelines, and anything else that should be top-of-mind regardless of the task.

The auto-injection mechanism is **CARL** — a UserPromptSubmit hook (`hooks/carl-loader.sh`) that reads the user's prompt, decides which domain rules apply, and prepends the matching rule files to context.

## Rule domains

| Domain | What | Always-on? |
|---|---|---|
| `common/` | Universal rules — coding-style, git-workflow, testing, security, agents, performance, patterns, definition-of-done | Yes |
| `content-system/` | Content production rules — caption-generation-enforcement, content-plan-enforcement | When content commands/skills fire |
| `python/` | Python-specific style rules | When user is working in Python |
| `typescript/` | TypeScript-specific style rules | When user is working in TS |

## What's in `common/`

| File | What |
|---|---|
| `coding-style.md` | Immutability requirements, file organization (200-400 lines typical, 800 max), error handling, input validation, code quality checklist |
| `git-workflow.md` | Conventional Commits format, PR workflow, feature implementation order (plan → build+tests → review → DoD → push) |
| `testing.md` | Min 80% coverage, TDD workflow, behavioral specs in `docs/test-specs/`, E2E auth pattern |
| `security.md` | Mandatory security checks before commit, secret management, response protocol |
| `agents.md` | Agent roster, slash commands, parallel execution patterns, hooks system |
| `performance.md` | Model selection strategy (haiku/sonnet/opus), context window management, extended thinking + plan mode |
| `patterns.md` | Skeleton projects, design patterns (repository, API response envelope) |
| `definition-of-done.md` | DoD checklist enforced by `session-retrospective.sh` — code/verification/docs/tracking/decisions/deploy |

## What's in `content-system/`

| File | What |
|---|---|
| `caption-generation-enforcement.md` | No freehand captions; use `unstuck/prompts/caption-generator.md`; Mirror pillar stops at Agitate; CTA matches pillar |
| `content-plan-enforcement.md` | Project lens rotation (max 2 of 6 weekly posts can be app/SaaS), tool mention limits (max 1 per file), PM jargon ban, hook cooloff (14d) |

## How CARL decides which rules to load

`hooks/carl-loader.sh` runs at every UserPromptSubmit. It:

1. Always loads `rules/common/*.md` (universal)
2. Scans the user's prompt for triggers:
   - File extensions (`.py` → python rules; `.ts`/`.tsx` → typescript rules)
   - Star-commands (`*dev` → development rules; `*review` → review rules; `*brief` → brief writing rules)
   - Topic keywords (e.g., "caption" → content-system rules)
3. Matches CLAUDE.md "RIGOR" triggers (settings.json, schema, manifest, hooks, plugins, MCP) → loads stricter validation rules
4. Concatenates the matched rule files into a system context block

The result: relevant rules show up automatically; irrelevant ones don't bloat context.

## Star-commands

CARL recognizes star-prefixed words as load-domain triggers:

- `*dev` → loads dev domain rules
- `*review` → loads review domain rules
- `*brief` → loads brief writing rules
- `*content` → loads content-system rules

Use them by prefixing your message: "*dev help me refactor the auth flow" → CARL loads the dev rule set.

## Rigor triggers

Editing certain files raises the rule rigor automatically:

- `settings.json`, `settings.local.json`
- Config files (`tsconfig.json`, `pyproject.toml`, etc.)
- Database schema files
- `CLAUDE.md`
- Plugin manifests
- MCP configurations
- Hooks

When CARL detects an edit to one of these, it injects extra validation rules — slower but safer.

## Why this design

Rules vs skills vs hooks:

- **Rules** are *passive* and *always-on* (within their domain). They shape the model's behavior baseline.
- **Skills** are *active* and *trigger-based*. They add capabilities when the user's request matches.
- **Hooks** are *imperative* and *lifecycle-bound*. They execute scripts at specific events (regardless of whether the model "remembers" to).

Use rules for things you want the model to *know* always. Use skills for things you want the model to *do* when matched. Use hooks for things you want to happen *every time* a lifecycle event fires.

## Adding a new rule

For a `common/` rule:

```sh
# Edit ~/.claude/rules/common/<name>.md
# Document the principle, examples, when it applies, what NOT to do
# Sync to repo:
cd ~/github/claude-config
./bin/sync.sh
git add -A && git commit -m "feat(rules): add <name>" && git push
```

For a new domain:

```sh
# Create ~/.claude/rules/<domain>/
# Add rule files
# Update CARL to recognize the new domain (edit hooks/carl-loader.sh)
# Sync to repo
```

The CARL loader's domain-detection logic lives in `hooks/carl-loader.sh` — edit there to register new triggers for a domain.
