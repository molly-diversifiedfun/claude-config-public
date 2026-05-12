# Agents Catalog

14 specialized subagent roles. Each runs in its own context window with its own model + tool palette. Invoked via the `Task` tool (programmatically) or via slash commands.

## The product engineering team

| Agent | Model | Owns | Tools | When to invoke |
|---|---|---|---|---|
| `product-lead` | Opus | `/plan` | Read, Write, Edit, Glob, Grep | Feature planning, problem definition, brief writing, breaking features into specs |
| `engineer` | Sonnet | `/build` | Read, Write, Edit, NotebookEdit (full code surface) | Implementation with TDD; tests ship in same commit |
| `designer` | Sonnet | direct | Read, Write, Edit, Playwright | UI components, layouts, flows, accessibility, visual QA via screenshots |
| `reviewer` | Sonnet | `/review` | Read-only | Pre-merge review; files CRITICAL/HIGH bugs to GitHub |
| `tech-researcher` | Sonnet | `/research` | Read, Glob, Grep, WebFetch, Context7 | Library docs, API behavior, third-party integration patterns |
| `debugger` | Opus | direct | Read, Write, Edit, Bash | Gnarly bugs; reproduces, isolates, root-causes; writes postmortems |
| `security` | Opus | direct (auto-spawned on supabase migrations/functions) | Read-only | Vulns, secret scanning, injection, auth/RLS bypass |
| `project-manager` | Haiku | direct | Read on code, Write on tracking | TASKS.md, HANDOFF.md, ADR filing, summaries |
| `memory-keeper` | Haiku | `/ship` Stage 1 + Stage 11 | Read, Write, Edit, Glob, Grep, Bash | Pre-flight pattern load (writes `.ship/<run>/patterns.md`); post-flight feedback capture (drafts → memory/). See `docs/ship-pipeline-v2.md`. |

## The content team

| Agent | Model | Owns | Notes |
|---|---|---|---|
| `content-social` | Sonnet | `/write social` | IG / LinkedIn / TikTok / Reels — pipeline-only, spawns `content-qa` before save |
| `content-longform` | Sonnet | `/write longform` | Books, ebooks, blogs, workbooks, brand PDFs — outline → sign-off → prose |
| `content-business` | Sonnet | `/write business` | Proposals, decks, sales emails — drafts only, never sends |
| `content-qa` | Haiku | direct (auto-spawned by other content agents) | Read-only 23-item checklist from `learned/qa-rules.md` — outputs PASS/FAIL + violations |
| `market-researcher` | Sonnet | direct | Sales/market research; people/company/social-signal verification — output is notes+facts, never prose |

## How agents differ from skills

| | Skills | Agents |
|---|---|---|
| Activation | Auto, via description match | Explicit (Task tool or slash command) |
| Context | Loads into main thread | Own context window |
| Model | Same as parent | Per-agent (haiku/sonnet/opus) |
| Tools | All parent tools | Restricted per-agent |
| Output | Continues main flow | Returns to parent |

You want an agent when:
- Work has a distinct *role* with its own quality bar
- You want a smaller/cheaper model (haiku for QA-style checks)
- You want a more powerful model than the main thread (opus for debugging)
- You want a restricted tool palette (read-only for review/security)
- You want clean handoff back to parent rather than continuing inline

## Model selection per agent

The team's model layout reflects cost/capability tradeoffs:

- **Haiku** (cheap, fast): `content-qa`, `project-manager`, `memory-keeper` — checklists, summaries, tracking, frontmatter-tagged glob filtering. Don't need reasoning depth.
- **Sonnet** (default): `engineer`, `designer`, `reviewer`, `tech-researcher`, all `content-*` writers, `market-researcher` — bulk of the work.
- **Opus** (deep reasoning): `product-lead`, `debugger`, `security` — high-leverage thinking, low-volume invocations.

If the team's pricing tiers shift, this layout gets retuned. See `~/.claude/CLAUDE.md` "Performance" section for current model selection guidance.

## Adding a new agent

`~/.claude/agents/<name>.md`:

```yaml
---
model: sonnet
description: One sentence — role + owner of which command + key constraint
tools:
  - Read
  - Write
  - Edit
---

# <Name>

## Role
What this agent does. Quality bar. What it does NOT do.

## Process
The steps the agent follows.

## Output format
What the agent returns to the parent.
```

Sync to repo via `bin/sync.sh` and push.
