# Skill Directory — Roles × JTBD × Skills

**Generated from:** `~/.claude/agent-skill-manifest.yaml` (v1)
**Last updated:** 2026-05-24

<!-- DO NOT EDIT - generated from agent-skill-manifest.yaml -->

## Roles

### builder

Code, infra, scripts, hooks, tools

**Pipeline owner:** `builder`

| JTBD | Owner | Slash | Skills |
|---|---|---|---|
| Ship a major feature end-to-end with spec, tests, review, and deploy | `builder` | `/ship` | `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, `superpowers:requesting-code-review`, `superpowers:finishing-a-development-branch` |
| Fix a bug quickly — no spec, minimal ceremony | `builder` | `/fix` | `superpowers:systematic-debugging`, `superpowers:verification-before-completion` |
| Plan a feature before building — spec, risks, task breakdown | `builder` | `/plan` | `superpowers:brainstorming`, `superpowers:writing-plans`, `compound-engineering:workflows:plan` |
| Add or modify a configuration flag, env var, or setting | `builder` | `/fix` | `update-config`, `superpowers:verification-before-completion` |
| Refactor an existing module without changing behavior | `builder` | `/build` | `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `simplify` |
| Extend the agent-skill manifest with a new JTBD definition | `builder` | `/ship` | `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:subagent-driven-development`, `superpowers:verification-before-completion` |
| Add a new pipeline-owner agent with full role wiring | `builder` | `/ship` | `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:subagent-driven-development`, `superpowers:verification-before-completion`, `superpowers:requesting-code-review` |
| Review a pull request before merge | `builder` | `/review` | `code-review:code-review`, `pr-review-toolkit:review-pr`, `differential-review:diff-review` |
| Audit code, auth flows, or migrations for security issues | `builder` | `—` | `everything-claude-code:security-review`, `everything-claude-code:security-scan`, `audit-context-building:audit-context` |

### creator

All content production (short-form + longform + business)

**Pipeline owner:** `creator`

| JTBD | Owner | Slash | Skills |
|---|---|---|---|
| Create a multi-slide Instagram carousel with on-brand voice | `creator` | `/write` | `brand-voice-router`, `carousel-writer`, `hooks`, `humanize-ai-writing`, `canva-carousel` |
| Write a long-form blog post or article | `creator` | `/write` | `brand-voice-router`, `conversion-copywriting`, `humanize-ai-writing`, `seo-audit` |
| Write a YouTube video script with hook, structure, and retention beats | `creator` | `/write` | `youtube-scriptwriting`, `brand-voice-router`, `hooks`, `humanize-ai-writing` |
| Write conversion-optimized copy for a landing page, email, or ad | `creator` | `/write` | `conversion-copywriting`, `brand-voice-router`, `humanize-ai-writing`, `marketing-psychology` |
| Build or tailor a resume from real evidence | `creator` | `/write` | `resume-rebuilder`, `humanize-ai-writing` |
| Write a <your-project-2> book chapter in the master-doc editorial style | `creator` | `/write` | `flamingo-doc-style`, `brand-voice-router`, `humanize-ai-writing`, `voice-extractor` |
| Repurpose one pillar piece into platform-ready content derivatives | `creator` | `/write` | `brand-voice-router`, `content-atomizer`, `hooks`, `humanize-ai-writing` |

### strategist

Marketing strategy + decision pipeline + diagnostic work

**Pipeline owner:** `strategist`

| JTBD | Owner | Slash | Skills |
|---|---|---|---|
| Make a decision between 2-4 options with structured reasoning | `strategist` | `—` | `decision-maker`, `devils-advocate`, `mental-models` |
| Stress-test an idea, plan, or decision through adversarial critique | `strategist` | `—` | `devils-advocate`, `mental-models`, `self-interview` |
| Plan a content strategy with pillars, calendar, and topic coverage | `strategist` | `—` | `content-strategy`, `content-calendar`, `keyword-research`, `marketing-psychology` |
| Audit a product, onboarding, or system for followability gaps | `strategist` | `—` | `followability-audit`, `mental-models`, `devils-advocate` |
| Diagnose why a side project is stuck and unstick it | `strategist` | `/unstuck` | `ai-build-partner`, `unstuck`, `mental-models`, `decision-maker` |

### researcher

Tech + market research + fact verification

**Pipeline owner:** `researcher`

| JTBD | Owner | Slash | Skills |
|---|---|---|---|
| Research a library, API, framework, or SDK for current usage | `researcher` | `/research` | `firecrawl`, `plugin_compound-engineering_context7:query-docs` |
| Research a market, competitor, prospect, or fact for verification | `researcher` | `/research` | `firecrawl`, `keyword-research` |

### operator

System care — deploys, plugins, retros, tracking, summaries

**Pipeline owner:** `operator`

| JTBD | Owner | Slash | Skills |
|---|---|---|---|
| Deploy a project to its target environment with smoke verification | `operator` | `/deploy` | `deploy`, `use-railway`, `ship-preflight` |
| Audit installed plugins for upstream drift and apply updates | `operator` | `/update-plugins` | `update-plugins` |
| Scan installed skills for consolidation candidates | `operator` | `/consolidate-skills` | `consolidate-skills`, `merge-skills` |
| Sync project docs and session progress to Notion wiki | `operator` | `/sync-notion` | `sync-notion` |
| Save current session state for continuity across sessions | `operator` | `/handoff` | `handoff`, `session-handoff` |
| Run a retrospective over recent sessions to surface patterns | `operator` | `/system-retro` | `system-retro`, `learn`, `update-memory` |

## Agents

### Pipeline owners

- **builder** (sonnet) — Pipeline owner for code, infra, scripts, hooks, and tools — owns /plan /build /ship /fix
- **creator** (sonnet) — Pipeline owner for all content production — short-form social, longform, and business deliverables
- **strategist** (sonnet) — Pipeline owner for marketing strategy, decision-making, diagnostics, and stuck-project unsticking
- **researcher** (sonnet) — Pipeline owner for tech research, market research, and fact verification
- **operator** (sonnet) — Pipeline owner for system care — deploys, plugin audits, skill consolidation, syncs, handoffs, and retros

### Utility specialists

- **product-lead** (opus) — Senior PM/Tech Lead — writes specs, plans, and brainstorms for L/XL feature work
- **designer** (sonnet) — UI/UX designer — components, layouts, accessibility, visual QA via Playwright
- **debugger** (opus) — Bug investigation — complex bugs, repros, root cause analysis
- **security** (opus) — Security auditor — read-only review of auth, migrations, secrets, and injection vectors
- **reviewer** (sonnet) — Code reviewer — pre-merge review, read-only, catches architectural issues
- **content-qa** (haiku) — Content QA — read-only checklist against learned/qa-rules.md
- **memory-keeper** (haiku) — Memory operations — /ship Stage 1 pre-flight pattern load + Stage 11 capture
