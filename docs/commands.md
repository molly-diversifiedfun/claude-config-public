# Slash Commands Reference

30 commands. Each is a `~/.claude/commands/<name>.md` file whose body becomes the prompt when typed.

## Workflow modes

The big-five — pick one based on scope:

| Command | When | What it does |
|---|---|---|
| `/fix` | Bugs, small changes | No spec, no review pipeline. Just fix. |
| `/build [feature]` | Standard feature | Lightweight spec → 3-5 agents → auto-proceed |
| `/ship [feature]` | Any code work | **Smart v3 (Phase 8.0).** Stage 0 calls Haiku 4.5 to pick S/M/L/XL scope; only stages that fit run. Each stage explicitly invokes a superpowers skill (brainstorming, tdd, verification-before-completion, requesting-code-review, finishing-a-development-branch). S = tdd + smoke only; M = +preflight+brainstorm+spec+impl+review+capture; L = +designer+research+subagent-driven-development; XL = +ADR+double memory-keeper. See `docs/ship-pipeline-v2.md`. |
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
| `/promote` | Promote a project-local feedback memory file into a cross-project learned pattern |
| `/deploy` | Deploy the current project |
| `/sync-notion` | Sync GitHub docs + session progress to a Notion wiki |

## Skill catalog + bake-off (Phase 7.2 / 7.3 / 7.4 / 7.7a)

| Command | What |
|---|---|
| `/skills "what you want to do"` | Semantic search over ~600 installed skills. Pre-filter by archetype + keyword grep → top-5 with rationale. Stopwords-tuned, stemming-controlled scoring. |
| `/bake-off "query"` | Tournament-test 3 candidate skills on the same task (`--yolo` = 1 untested skill self-rate; `--control` = known-good vs yolo). Rolling win/loss tallies at `~/.claude/data/bake-off-stats.tsv`. |
| `/consolidate-skills` | One-shot static analysis to find duplicate skills. Composite score = description Jaccard + body-token Jaccard + bake-off shared losses + elimination flag. Adds LLM-judge for the ambiguity band. |
| `/merge-skills <pathA> <pathB>` | Sonnet synthesizes a merged draft to `~/.claude/skills/_drafts/`. Acceptance is manual (`mv` + `rm -rf` originals). |

## Pipeline observability (Phase 7.7b / 7.7c / 8.0 / 8.1)

| Command | What |
|---|---|
| `/system-retro` | One-shot retrospective over last 20 sessions. Haiku judge scores 4 dimensions + primary_gap + process_pattern label. Synthesis judge surfaces cross-cutting themes. |
| `/ship-preflight` | Probe external dependencies (CLI commands, env vars, files, URLs) before `/ship` commits. |
| `/ship-scope-replay` | Re-classify recent sessions' first user prompts through Stage 0 — useful for classifier calibration. |
| `/ship-skill-status` | Report which superpowers skills fired in the current `/ship` run vs which were expected per scope (advisory, never blocks). |
| `/update-plugins` | Scan installed plugins via `git ls-remote` for upstream drift; prompt to update. |

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
