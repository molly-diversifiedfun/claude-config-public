# Slash Commands Reference

18 commands. Each is a `~/.claude/commands/<name>.md` file whose body becomes the prompt when typed.

## Workflow modes

The big-five — pick one based on scope:

| Command | When | What it does |
|---|---|---|
| `/fix` | Bugs, small changes | No spec, no review pipeline. Just fix. |
| `/build [feature]` | Standard feature | Lightweight spec → 3-5 agents → auto-proceed |
| `/ship [feature]` | Major feature | **Memory-aware v2.** 11-stage pipeline: pre-flight (memory-keeper loads tagged patterns) → existing 9-agent flow → Stage 9 Deploy+Smoke (hook-gated: 3-deploy rule, observability, smoke) → capture (memory-keeper drafts feedback). v1 vertical slice. See `docs/ship-pipeline-v2.md`. |
| `/write` | Copy / docs / book chapters / brand content | Loads writing skills + brand voice |
| `/escalate-to [mode]` | Mid-flight | Mode transition when current mode isn't enough — escalates without losing work |

## Planning + research

| Command | What |
|---|---|
| `/plan [feature]` | Full define → explore → spec pipeline (invokes product-lead) |
| `/research [topic]` | Tech/library/integration research (invokes tech-researcher) |

## Review

| Command | What |
|---|---|
| `/review` | Pre-merge code review (invokes reviewer) |
| `/moa-review` | Multi-model Expert Panel review of current changes |
| `/moa-debate` | Multi-round debate between models on a complex question |
| `/moa` | Single multi-model ensemble query (adaptive routing with research) |

## Project lifecycle

| Command | What |
|---|---|
| `/init-project` | Bootstrap a new project with proper Claude Code config (CLAUDE.md template, rules, etc.) |
| `/handoff` | Save current session state for continuity (skill: `handoff`) |
| `/learn` | Save learnings from this session to long-term memory |
| `/deploy` | Deploy the current project |
| `/sync-notion` | Sync GitHub docs + session progress to a Notion wiki |

## Specialty

| Command | What |
|---|---|
| `/canva-carousel` | Generate IG carousel via Canva template + QA + auto-fix |
| `/video-story [concept]` | AI-generated videos with character consistency + storytelling craft |
| `/unstuck [phase]` | Run the Unstuck Coach — modular coaching for side-project shippers (`diagnose|audit|scope|validate|sprint|launch|roadmap|full`) |
| `/new-project-template` | Drops a CLAUDE.md template for a new project |

## How modes auto-proceed

Each workflow mode (`/fix`, `/build`, `/ship`, `/write`) has phase gating logic baked in. Default behavior: auto-proceed unless an agent reports `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.

This means typing `/build add a settings page` produces a full feature without intermediate "should I continue?" prompts — the pipeline only stops on real blockers.

To pause for review: explicitly tell the agent "stop after spec" or "wait for my approval before implementing."

## Adding a new command

`~/.claude/commands/<name>.md`:

```yaml
---
description: One-line summary shown in /help
argument-hint: [optional|argument|values]
---

The body of this file becomes the prompt when the user types /<name>.

Refer to $1, $2, etc. for positional arguments.
```

Or for commands without arguments, skip the YAML and just write the prompt:

```markdown
First line is the description shown in /help.

Then the body is the actual prompt.
```

Sync to repo via `bin/sync.sh` and push.
