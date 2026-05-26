# Skills Catalog

38 custom skills, organized by purpose. Each skill auto-invokes when the user's request matches its trigger phrases — no slash command needed.

## Catalog system (Phase 7.1 / 7.2 / 7.3 / 7.4)

The growing universe of installed skills (~600 across the ~/.claude/ + plugin trees) is managed by a catalog system:

- **`projects.yaml`** — path → archetype mapping (web-app, telegram-bot, content-pipeline, python-cli, video-pipeline, infra-config, brand-content). Resolution: exact match → longest-prefix → auto-detect → "unknown" fallback.
- **`skill-archetypes.yaml`** — skill name → archetype tags (`always-on` or one or more archetypes). A skill fires for the active archetype if its tag list contains the archetype OR `always-on`.
- **`work-type-chains.yaml`** — first-match regex on prompt → ordered chain of work types (build / plan / review / debug / research / write-content / memory / design / infra).
- **`~/.claude/data/bake-off-stats.tsv`** — rolling tallies (skill_name, appearances, wins, losses, last_run_iso) from `/bake-off` tournaments. Skills with ≥3 appearances AND 0 wins are auto-eliminated from candidate lists.
- **`scripts/skills-prefilter.sh`** — shared candidate-selection logic. Used by `/skills`, `/bake-off`, and `hooks/inject-skills-for-agent.sh`.

## ai-build-partner

`ai-build-partner` is in the private repo but ships separately in the public [`claude-skills`](https://github.com/<your-github-username>/claude-skills) repo. Not in the public `claude-config-public` mirror.

## Writing & Voice

| Skill | Triggers on |
|---|---|
| `humanize-ai-writing` | "make this sound human", "de-AI this", "sound more natural", "this sounds like AI", "remove AI tells", "this reads like ChatGPT". Two modes: interactive (annotated report + user-approved fixes) and pipeline (auto-apply). Subsumes the former ai-tell-killer. |
| `voice-extractor` | "create a voice profile", "make AI sound like me", "capture my writing voice" |
| `brand-voice-router` | Any content request — auto-routes to <your third brand> / <your brand> / <your second brand> voice |

## Content production

| Skill | Triggers on |
|---|---|
| `carousel-writer` | Generating Instagram carousel JSON for Canva template injection. Includes multi-platform specs table (IG/LI/X/FB) for cross-platform repurposing. |
| `video-script` | Batch talking-head Reels scripts (60-90s) — solo creator filming sessions |
| `youtube-scriptwriting` | Long-form YouTube script with structured retention |
| `repurpose` | Turn a pillar piece into 6 platform derivatives (Welsh's 1-3-5 method) |
| `hooks` | 5 brand-voice-matched hook variants for any topic |
| `content-atomizer` | Long-form → 15+ platform-ready assets |
| `content-strategy` | Pick what content to create, what topics to cover |
| `content-calendar` | Monthly + weekly social content calendars, mix ratios, theme days |
| `social-content` | LinkedIn / Twitter / IG / TikTok / Facebook content optimization |
| `email-sequence` | Drip campaigns, lifecycle email programs, automated flows |
| `direct-response-copy` | Sales pages, sales emails, ads — DR principles |
| `copywriting` | Homepage / landing / pricing / feature / about / product page copy |
| `marketing-psychology` | Mental models / cognitive bias / behavioral science applied to marketing |

## Thinking & Decisions

| Skill | Triggers on |
|---|---|
| `mental-models` | "I need to decide", "what could go wrong", "why does this keep happening" — 12-model facilitated thinking |
| `decision-maker` | Choosing between 2-4 options — produces a one-page brief with confidence + kill conditions |
| `devils-advocate` | "challenge this", "poke holes", "red team this", "pre-mortem" — adversarial only, by design |
| `self-interview` | "I need to think through", "I know what I think but can't articulate it" — 5-channel Socratic method |
| `ask-me-the-questions` | Vague request — interviews user (2-5 adaptive Qs) before delivering |
| `brainstorm` | Multi-session ideation across days/weeks via versioned markdown |

## SEO & Research

| Skill | Triggers on |
|---|---|
| `seo-audit` | Auditing/diagnosing SEO issues, technical SEO, ranking diagnosis |
| `keyword-research` | Discovering high-value SEO keywords with intent + difficulty + topic clusters |

## Career

| Skill | Triggers on |
|---|---|
| `resume-rebuilder` | Resume creation/improvement/tailoring + cover letters from real evidence |

## Business operations

| Skill | Triggers on |
|---|---|
| `audit-roadmap` | Verify roadmap "done" stories against actual code (VERIFIED/PARTIAL/FAKE) |
| `update-roadmap` | Surgical roadmap HTML updates without full rewrites |
| `code-documenter` | Comprehensive doc generation for coding projects (incremental, multi-audience) |

## Tooling

| Skill | Triggers on |
|---|---|
| `nano-banana` | All image generation (blog featured, YouTube thumbs, icons, illustrations) via Gemini CLI |
| `firecrawl` | Web scraping, search, crawling, browser automation — clean LLM-optimized markdown |
| `blitzreels-carousels-tiktok` | TikTok carousel projects via BlitzReels API |
| `swarm-gate` | Quality gate after parallel agent waves — checks doc freshness, ADRs, test sync |

## Meta (CARL system)

| Skill | Triggers on |
|---|---|
| `carl-help` | "what is CARL", "how does CARL work", "CARL help" |
| `carl-manager` | "make this a rule", "add this to CARL", "create a domain for X" |

## Workflow

| Skill | Triggers on |
|---|---|
| `handoff` | End of work session, context switching, before a break — captures continuity doc |

## Pattern memory (`learned/`)

The `learned/` skill is a directory of cross-project pattern files synthesized from past feedback. Currently:

- `ai-tell-avoidance.md`
- `competitive-history.md`
- `delegation-discipline.md`
- `deploy-iteration-discipline.md`
- `documentation-after-build.md`
- `hook-performance.md`
- `mass-rewrite-mechanics.md`
- `n8n-production-patterns.md`
- `never-fabricate.md`
- `nonfiction-sourcing.md`

These get loaded contextually by skills that depend on the patterns (e.g., `humanize-ai-writing` reads `ai-tell-avoidance.md`).

## Legend — when to add a new skill

You should add a skill (instead of a rule, agent, or command) when:
- The capability has clear, specific trigger phrases
- It's not always-on (rules are for always-on)
- It doesn't need its own context window or tool palette (agents are for that)
- The user will invoke it conversationally, not via a slash command (commands are for that)

Skill creation pattern: write `~/.claude/skills/<name>/SKILL.md` with YAML frontmatter:
```yaml
---
name: my-skill-name
description: Use when ... Trigger on phrases like "X", "Y", "Z". NOT for [edge case] — use [other-skill] instead.
---
```

Then the body is the actual instructions Claude follows when the skill loads. Sync to repo via `bin/sync.sh` and push.
