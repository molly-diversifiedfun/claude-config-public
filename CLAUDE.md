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
| content-social | sonnet | Short-form social (IG/LI/TT/Reels) | brand-voice-router, humanize-ai-writing, repurpose, hooks, carousel-writer |
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
| Full Pipeline | `/ship` | Any code work — auto-classifies scope (S/M/L/XL) and runs only the stages that fit. **Smart v3 (Phase 8.0, 2026-05-23)** — Stage 0 calls Haiku 4.5 to pick scope; each stage explicitly invokes a superpowers skill (brainstorming, tdd, verification-before-completion, requesting-code-review, finishing-a-development-branch). S = tdd + smoke only; M = +preflight+brainstorm+spec+impl+review+capture; L = +designer+research+subagent-driven-development; XL = +ADR+double memory-keeper. See `commands/ship.md`. |
| Content | `/write` | Copy, docs, book chapters, brand content |
| Escalate | `/escalate-to` | Mode transition when scope grows |

**Phase gating:** Auto-proceed unless agent reports DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED.

## CARL Rule System

CARL auto-injects domain rules via `carl-loader.sh` on every UserPromptSubmit.
- **GLOBAL + CONTEXT** always on. **COMMANDS** via star-commands (`*dev`, `*review`, `*brief`).
- **RIGOR** triggers on: settings.json, config, schema, manifest, hooks, tsconfig, CLAUDE.md, plugins, MCP.
- Domains: GLOBAL, CONTEXT, WORKFLOW, RIGOR, COMMANDS, CONTENT-RULES, WRITING, N8N, **DESIGN** (auto-loads `learned/ai-design-tells` + brand rules on UI/design keywords like design/ui/mockup/hero/landing/component/tsx/branding), **SCOPE** (triggers on scope tokens like all/every/each + collection noun — fires restate-scope rule).
- Use `carl-manager` skill to create/edit. Use `carl-help` for reference.

## Skill Collections

Custom skills (in `~/.claude/skills/`):
- **Learned patterns:** `learned/` — 16 cross-project pattern files synthesized from feedback (all carry v2 frontmatter)
- **Brand voice:** `brand-voice-router/` — all 3 brands + you Direct, with plugin integration
- **Writing:** `humanize-ai-writing/`, `voice-extractor/`
- **Thinking:** `mental-models/`, `devils-advocate/`, `decision-maker/`, `self-interview/`, `ask-me-the-questions/`
- **Content:** `brainstorm/`, `code-documenter/`, `handoff/`
- **Dev tools:** `carl-manager/`, `carl-help/`, `nano-banana/`, `firecrawl/`

External (not auto-discovered):
- Writing books: `~/github/claude-code-toolkit/skills/non-fiction-book-factory/`
- Writing ebooks: `~/github/claude-code-toolkit/skills/ebook-factory/`
- Writing craft: `~/github/claude-code-toolkit/skills/writing/`

### `/skills` semantic catalog (Phase 7.2, 2026-05-20; 7.2.2 patch 2026-05-21)

`/skills "what you want to do"` — semantic search over ~600 installed skills. `scripts/skills-prefilter.sh` pre-filters by archetype + keyword grep (≤30 candidates, 3 priority tiers: Pool1∩Pool2 → Pool2 only → Pool1 only), then the parent Claude turn ranks the top 5 with rationale. Reuses `skill-archetypes.yaml` from Phase 7.1. Kill: `SKILLS_CATALOG=off`. No args → usage hint. 10 unit tests at `test/skills/`.

**Phase 7.2.2 (2026-05-21):** Pool 2 membership now requires a description-line keyword match (score ≥ 1), not just a whole-file body grep. Whole-file grep stays as a cheap prefilter, but body-only matches (where a keyword appears in examples / triggers / instructions but the description has nothing relevant) are dropped before tier sort. Eliminates the bug where score=0 always-on skills crowded Tier A and pushed semantic matches in Tier C below them via alphabetical tiebreak (`ask-me-the-questions` winning slot 1 over `humanize-ai-writing` for humanize queries). Candidate count for typical queries drops ~5-10× (e.g. 202 → 37 for "humanize this paragraph"). Test 07 covers regression.

**Phase 7.4 (2026-05-21):** `/skills` output now consumes per-skill stats from `~/.claude/data/bake-off-stats.tsv` via shared helpers in `scripts/bake-off-lib.sh`. Two new behaviors: (1) skills with `≥3 bake-off appearances AND 0 wins` are dropped from the candidate list entirely (kill switch: `BAKEOFF_ELIMINATE=off`); (2) skills with `<3 appearances` get a column-4 `untried` flag, rendered as `✨` prefix in the top-5 display to drive bake-off adoption on under-tested skills. Tests 08-09 cover both behaviors using `mktemp -d` + `BAKEOFF_STATS_FILE` env-var override (per `feedback_test_fixtures_must_not_write_live_data_files.md`).

**Phase 7.2.3 (2026-05-21):** Two scoring-quality calibrations from `feedback_phase_7_2_2_residual_calibration_targets.md`. (1) `STOPWORDS` extended with five high-frequency low-signal generics from corpus analysis (`use`=52% of descriptions, `skill`=19% self-reference, `any`/`should`/`before` ~8% each). (2) Description-match stemming tightened from `\b<kw>` (unbounded prefix) to `\b<kw>(s|es|d|ed|ing)?\b` (controlled regular-suffix stems with trailing word boundary). Eliminates the false-positive class where `\bmake` matched `decision-maker` inside descriptions. Real writing skills (`copywriting`, `docs:write-concisely`) now surface in top 5-7 for humanize queries instead of being displaced by alphabetical noise. Test 10 covers both calibrations; full prefilter suite 10/10.

**Phase 7.5 (2026-05-21):** Subagents now receive top-3 prefilter-matched skills at dispatch time via new `hooks/inject-skills-for-agent.sh` (PreToolUse:Agent). Allowlist: 7 implementation-style subagents (engineer, designer, debugger, content-social/longform/business, tech-researcher). Skills appear as a prepended context block in the subagent's prompt (via `hookSpecificOutput.updatedInput.prompt`). Prefilter is the same Phase 7.2 script; no scoring changes. Soft-fails open on every internal error — prefilter timeout, missing fields, <3 candidates → exit 0 (no injection, no block). Log: `~/.claude/logs/inject-skills-for-agent.log` (NDJSON, one line per fire/skip). Tests at `~/.claude/test/hooks/` (5 tests, 12 assertions). Kill: `SKILL_INJECT_FOR_AGENT=off`.

**Phase 7.5.1 (2026-05-21):** Wraps the Phase 7.5 injection block in stable HTML-comment markers (`<!-- phase-7-5-injected-skills v1 -->` ... `<!-- /phase-7-5-injected-skills -->`) so Phase 7.6 can detect "was this dispatch injected?" by sniffing `tool_input.prompt` directly instead of log-joining. Two-line patch to `inject-skills-for-agent.sh`; new regression test at `test/hooks/06-marker-emitted.sh`. Full Phase 7.5 hooks suite stays green (6 tests, 15 assertions).

**Phase 7.6 (2026-05-21):** Post-dispatch LLM-judge that grades whether implementation subagents used the skills Phase 7.5 surfaced. Two-part hook at `hooks/agent-eval.sh`: `--enqueue` (PostToolUse:Agent) snapshots (task + injected_skills + agent_return) to `~/.claude/data/agent-eval-queue/<ts>.json` when the Phase 7.5.1 marker block is present in the prompt; `--drain` (Stop hook, after `session-retrospective.sh`) invokes `claude -p --model claude-haiku-4-5-20251001` per queued snapshot, validates JSON via jq with retry-once-on-bad-JSON, appends judgments to `~/.claude/data/agent-eval.jsonl` (canonical, JSONL-compact via `jq -n -c`). Multi-field schema: `used_injected_skill`, `which_skill`, `better_skill_suggested`, `quality_score` (1-5), `rationale`. Hard rules in judge prompt forbid hallucinated skill names per `learned/never-fabricate`. Logging-only — no auto-action on judge output. Caps: 20 files / 300s per drain, 30s per eval. `timeout`/`gtimeout`/bare fallback in `run_judge` for macOS without coreutils. Soft-fails open everywhere; never blocks the user's session. Kill: `AGENT_EVAL=off` (full), `AGENT_EVAL_DRAIN=off` (collect snapshots without spending tokens). Tests at `~/.claude/test/agent-eval/` (9 tests, 38 assertions). Log: `~/.claude/logs/agent-eval.log` (NDJSON, one line per fire/skip/judge).

### `/consolidate-skills` catalog caretaker (Phase 7.7a, 2026-05-22)

`/consolidate-skills` — one-shot static analysis of installed skills across `~/.claude/skills/` + `~/.claude/plugins/cache/**/skills/`. Composite scoring per pair: description Jaccard (weight 0.55, with Phase 7.2.3 STOPWORDS regex-parsed from `scripts/skills-prefilter.sh` at startup) + bake-off shared losses (0.30, capped at 5) + Phase 7.4 elimination flag (0.15). Outputs tiered markdown report (HIGH ≥0.55 / MEDIUM 0.30-0.55 / LOW 0.15-0.30 OR any plugin+plugin pair, demoted from HIGH/MEDIUM). Drop floor 0.15 applies universally. Each tier capped at top 50 by composite to keep reports scannable. Recommendation verbs derived by source pair: user+user → `merge: keep <winner>, delete <loser>`; user+plugin → `delete user-installed` or `keep user (override)`; plugin+plugin → informational only. Report at `~/.claude/data/skill-consolidation-reports/<ISO>.md`. Read-only — user runs `rm` manually. Soft-fails open: missing bake-off data → Jaccard-only fallback + footer warning. Python 3 stdlib only.

**Signal coverage (2026-05-22 dogfood, 965 skills):** caught 1552 plugin-cache duplicates (same skill installed via multiple plugins; demoted to LOW with "informational only" verb). Did NOT surface expected user-pair `humanize-ai-writing ↔ voice-extractor` (Jaccard 0.138 < 0.15 floor) — empirical finding that description-Jaccard catches lexical/literal overlap but not cross-vocabulary semantic overlap. Phase 7.7a.1 (deferred) would add body-token analysis or LLM-judge for semantic catching.

**Phase 7.7a.1 (2026-05-22):** Added body-token Jaccard as a fourth signal. Body = SKILL.md content with frontmatter + fenced code blocks stripped (two regex passes); tokenized via the same `tokenize()` used for descriptions (lowercase + alpha-only + STOPWORDS strip). New weights: desc=0.35, body=0.20, losses=0.30, elim=0.15 (sum still 1.0). Jaccard-only fallback rescales `(W_DESC*desc_j + W_BODY*body_j) / 0.55` so tier cuts stay comparable. Pair row format gains `desc_jaccard` + `body_jaccard` columns. New CLI debug flags `--extract-body <path>` and `--composite-test`. Test suite expanded from 8 → 11 (all GREEN). **Dogfood 2026-05-22 (965 skills, no bake-off coverage):** `humanize-ai-writing ↔ voice-extractor` now scores composite=0.156 (desc_j=0.138, body_j=0.187) — clears 0.15 floor but ranks 2801 of 2982 pairs above floor, so it's hidden by TIER_CAP=50. Top 50 LOW is entirely plugin+plugin demoted-HIGH duplicates (composite=0.550). Body-Jaccard at W_BODY=0.20 was not strong enough to surface this cross-vocab case — Phase 7.7a.2 (LLM-judge) becomes the real next step. Honest signal-limit finding per `learned/never-fabricate`.

**Phase 7.7a.2 (2026-05-22):** Added LLM-judge layer for cross-vocab semantic overlap. After Jaccard tier assignment, pairs in the "ambiguity band" (composite 0.15-0.30, non-plugin+plugin) get sent to Haiku 4.5 (`claude-haiku-4-5-20251001`) via `claude --bare -p --output-format json --json-schema ... --system-prompt ...`. The `--bare` flag is critical — it skips CLAUDE.md/skills/hooks context loading (~105k tokens), dropping per-call cost from $0.13 to $0.006 (22×). Output is an envelope `{"type":"result","result":"<inner>",...}`; `result` may be markdown-fenced JSON which `_strip_fences()` handles. Hardened prompt: few-shot inline example, literal `true`/`false`, retry-once-on-bad-JSON per `learned/llm-judge-needs-retry-and-defensive-parse`. Verdicts cached at `~/.claude/data/skill-judge-cache.jsonl` keyed by `sha256(sorted [pathA:bodyA, pathB:bodyB])` — auto-invalidates on skill edits. 8 parallel workers, 1000-pair / 180s caps with `pool.shutdown(wait=False, cancel_futures=True)` per `feedback_threadpool_exit_waits_in_flight_by_default`. Pairs where `overlap=true AND confidence≥4` get promoted to a new SEMANTIC tier at the TOP of the report (above HIGH); cap=20, sorted (confidence desc, composite desc). Original Jaccard tier still shown via "(also in <TIER>)" annotation. Default-on; kill switch `SKILL_JUDGE=off` or `--no-judge`. Test suite expanded from 11 → 14. Parse failures route to `~/.claude/data/skill-judge-failures/` for triage. **Dogfood 2026-05-22 (981 skills, jaccard-only mode):** 11 user-pair candidates surfaced; judge correctly cleared 9 with high confidence (incl. target pair `humanize-ai-writing ↔ voice-extractor` → overlap=false, confidence=5 — vindicates the original low Jaccard signal). 1 real semantic overlap caught: `repurpose ↔ video-script` (overlap=true, confidence=4, judge note: "both generate 60-90s Reel scripts with the same Hook→Problem→Insight structure"). Calibration findings: 30s per-call timeout still occasionally tight (~10-25% timeout rate on first attempt); confidence threshold of 4 correctly excluded 2 borderline pairs at confidence=3. Full mode without bake-off losses squashes user-pair composites below the 0.15 floor (separate calibration issue — Phase 7.7a.1/7.7a calibration follow-up).

**Phase 7.7a.3 (2026-05-22):** Two calibration follow-ups from 7.7a.2 dogfood. (1) `JUDGE_TIMEOUT_S` 30→60s (first-attempt timeout rate was ~10-25% at 30s with `--bare` p95 latency variance; 180s wall budget still bounds the run). (2) Mode-detection fix: empty `bake-off-stats.tsv` (header-only, zero data rows) was triggering full-mode composite scoring (no rescale), which squashed user-pair composites below the 0.15 floor and emptied the ambiguity band. Now `elim_available = bool(eliminated_set)` (drops the `or Path().exists()` clause), so file-exists-but-empty is treated same as file-missing for mode detection. Judge layer activates naturally on real catalogs without env-var workaround. Test 15 covers the regression. 15 unit tests total.

**Phase 7.7a.4 (2026-05-22):** Added `/merge-skills <pathA> <pathB>` companion tool for synthesizing SEMANTIC-tier candidates into a single merged draft. Sonnet 4.6 (`claude-sonnet-4-6`) via `claude --bare -p --output-format text --no-session-persistence --system-prompt ...`; 120s timeout. Writes draft to `~/.claude/skills/_drafts/<sonnet-proposed-name>/SKILL.md` — read-only on originals (the script NEVER deletes, modifies, or renames source skills). Prints `diff -u` vs both originals to stderr; prints accept/reject instructions to stdout. Acceptance is manual: `mv ~/.claude/skills/_drafts/<name> ~/.claude/skills/<name>` + `rm -rf` the originals if accepting. Mocked via `MERGE_CLAUDE_CMD` (test isolation via `MERGE_DRAFTS_ROOT` + `MERGE_SKILLS_ROOT`). 4 unit tests at `~/.claude/test/merge-skills/`. Kill: `MERGE_SKILLS=off`. **Dogfood 2026-05-22**: 3 candidate pairs attempted; 1 succeeded — `copywriting ↔ direct-response-copy → conversion-copywriting` (high-quality merge preserving direct-response architecture + general copywriting principles; Sonnet proposed creative name, not either original; description spans both skills' triggers). 2 pairs (`repurpose ↔ content-atomizer`, `social-content ↔ content-atomizer`) hit `MERGE_TIMEOUT_S=120` on 600+-line combined inputs — Phase 7.7a.5 candidate: env-var override for `MERGE_TIMEOUT_S` (same pattern as Phase 7.7a.3's `JUDGE_TIMEOUT_S` 30→60s bump).

**Kill:** `SKILL_CONSOLIDATE=off` (analyzer), `SKILL_JUDGE=off` (judge layer only), `MERGE_SKILLS=off` (synthesis tool). 15 + 4 unit tests at `~/.claude/test/consolidate-skills/` and `~/.claude/test/merge-skills/`.

### `/update-plugins` upstream drift detector (Phase 7.7b, 2026-05-22)

`/update-plugins` — one-shot scan of installed plugins in `~/.claude/plugins/installed_plugins.json`. For each install, runs `git ls-remote origin HEAD` (8 parallel workers, 10s per-call timeout, 90s total wall-clock cap) and compares to the recorded `gitCommitSha`. Classifies as DRIFTED / CURRENT / SKIPPED:<reason>. Writes markdown report at `~/.claude/data/plugin-update-reports/<ISO>.md`. If drift > 0, prompts user (all / select / none) and shells out to `claude plugin update <id>` for chosen plugins. Restart required after apply. Read-only against `installed_plugins.json` — delegates state mutation to Claude Code's plugin machinery.

**Kill:** `PLUGIN_UPDATE=off`. 8 unit tests at `~/.claude/test/update-plugins/`.

### `/system-retro` process retrospective (Phase 7.7c, 2026-05-23)

`/system-retro` — one-shot retrospective over the N most recent Claude Code sessions. Walks `~/.claude/projects/*/*.jsonl`, filters by mtime + `MIN_SESSION_BYTES=4000` (skips ~130-byte metadata-only files spawned by every `claude --bare` call), filters out `agent-*.jsonl` (subagent dispatches). Per session: extracts mode signals (slash-command counts via anchored regex `(?<![A-Za-z])/ship\b` etc, `superpowers:*` invocations, smoke evidence text hits), tool + subagent counts, first/last user message, last assistant message. Joins each session window with `git log` on resolved cwd, `hook-blocks.log` entries (cwd-filtered), and `agent-eval.jsonl` Phase 7.6 judgments.

Per-session Haiku 4.5 judge (`claude --bare -p --output-format json`, 90s timeout, 8 parallel workers) scores 4 dimensions 1-5: `shipped_and_smoked`, `incremental_value`, `mode_fit`, `time_to_done_vs_scope`. Plus `primary_gap` (one sentence) + `process_pattern` (kebab-case label: `shipped-clean`/`shipped-no-smoke`/`shipped-scope-creep`/`stuck-mid-impl`/`research-only`/`planning-only`/`abandoned`/`calibration-followup`/`tooling-meta`/`unclear`). A second synthesis judge (120s timeout) runs over all primary_gap strings to surface cross-cutting themes. Report at `~/.claude/data/system-retro/<ISO>.md`: per-mode aggregate table, process-pattern counts, top-3 exemplars + bottom-3 anti-exemplars by combined score, synthesis themes, raw session table.

**`--json-schema` calibration finding:** Haiku 4.5 with `--json-schema` flag returns empty `result` field on the 6-field schema (api still costs ~25s + ~2500 output tokens — model is reasoning through structured-output mode but never commits). Dropped the flag, replaced with strict system-prompt ("Your ENTIRE response must be a single JSON object... Start with '{' and end with '}'") + inline JSON template in user prompt + defensive `_extract_json_object()` brace-counter parser with retry-once. Reliably produces 20/20 verdicts in ~95s. Honest signal-limit per the Phase 7.7a/b pattern: `--json-schema` works for the 3-field schema in `/consolidate-skills` but fails at 6 fields with mixed types — calibration follow-up if richer constraints needed.

**Slug-encoding finding:** Claude Code's transcript dir slugs map both `/` AND `.` to `-` (so `$HOME/github/<your-bot>` → `<your-workspace>-<your-bot>`). Reverse-parsing the slug is fundamentally lossy (`user.name` and `user-name` are indistinguishable post-encoding). Solved by forward-built index: walk likely cwd roots (`~`, `~/github`, `~/Desktop`, `~/Downloads`, `~/.claude`, `/private/tmp`, `/tmp`) two-deep, compute each real dir's slug, build `dict[slug, str(real_path)]`. Regression test at `test/system-retro/08-cwd-slug-roundtrip.sh`.

**Dogfood 2026-05-23 (20 sessions, last ~12 hours):** Initial run (no aggregate floor): `raw` (n=16) shipped+smoked=2.2; `ship` (n=2) 4.0; `superpowers` (n=2) 4.0. Looked like ship + superpowers double raw on shipping.

**Phase 8.0 follow-up (aggregate floor 2026-05-23 12:52):** Added `MIN_AGG_DURATION_MIN=5.0` + `MIN_AGG_TOOL_CALLS=5` filter for per-mode averages (raw table keeps all sessions for transparency, only aggregates exclude floor-failures). Re-run on same 20: 11/20 sessions excluded (tiny abandoned <your-project-2> shells with 0-2 tools in <2 min). Corrected per-mode aggregates: `raw` (n=6) shipped+smoked=4.0, incr=4.0, fit=4.0, scope=3.5; `ship` (n=2) 4.0/4.5/4.0/3.5; `superpowers` (n=2) 4.0/5.0/4.0/3.0; `build` (n=1) 2.0/4.0/2.0/2.0. **The true finding is much narrower than the original story** — raw/ship/superpowers all ship at ~4.0 on real sessions; the original "raw is half" was aggregation noise. superpowers leads on incremental value (5.0). build's n=1 was a calibration-followup session (low ship, fine incremental). This validates Phase 8.0's design choice — making /ship scope-adaptive rather than pushing everything into /ship. Honest empirical correction per `learned/never-fabricate`.

**Phase 7.7c.1 (2026-05-23 ~12:30):** Extended `_scan_tool_uses()` to collect `input.skill` from every `Skill` tool_use block (not just text-regex). Eliminates the bucketing bias where `Skill(superpowers:foo)` invocations got bucketed as `raw`. Empirical impact on the 2026-05-23 sample: 0 sessions re-classified (the 16 raw sessions didn't use Skill() much — most were content production runs or tiny abandoned shells). Detection still important for future sessions where Skill() is more common.

**Kill:** `SYSTEM_RETRO=off`. Env-var overrides for testing: `SYSTEM_RETRO_PROJECTS_DIR`, `SYSTEM_RETRO_HOOK_BLOCKS`, `SYSTEM_RETRO_AGENT_EVAL`, `SYSTEM_RETRO_REPORT_DIR`, `SYSTEM_RETRO_N` (default 20), `SYSTEM_RETRO_NO_JUDGE` (extraction-only dry run, zero tokens), `SYSTEM_RETRO_CLAUDE_CMD`. 8 unit tests at `~/.claude/test/system-retro/` covering extraction, discovery filters, window joins, judge round-trip (mocked), report render, kill switch, extraction-only mode, slug round-trip.

### `/ship` Smart pipeline (Phase 8.0, 2026-05-23)

`/ship` rebuilt as a scope-aware pipeline that explicitly binds superpowers skills to stages. Direct response to the Phase 7.7c finding that the original /ship had structural overhead (11 always-on stages) AND didn't invoke superpowers at any gate (TDD / brainstorming / verification-before-completion referenced as flavor text in stage descriptions, never enforced).

**Stage 0 — scope classify (NEW):** `scripts/ship-scope-classify.py "<ask>"` — Haiku 4.5 via `claude --bare -p` (30s timeout), returns `{"scope":"S|M|L|XL","rationale":"..."}`. Soft-fails to S on any failure (smallest-safe default). 5 unit tests at `~/.claude/test/ship-scope-classify/`. Kill switch: `SHIP_SCOPE=off` → defaults to M. Smoke 2026-05-23 (4 test asks): 4/4 correct classification (typo→S, slack OAuth→M, payment migration→L, monolith split→XL).

**Scope → stage matrix:**

| Scope | Stages run | Required superpowers skills |
|---|---|---|
| S | 6 + 9 | `tdd`, `verification-before-completion` |
| M | 1 + 2 + 3 + 6 + 7 + 9 + 10 + 11 | `brainstorming`, `tdd`, `verification-before-completion`, `requesting-code-review`, `finishing-a-development-branch` |
| L | 1 + 2 + 3 + 4* + 5* + 6 + 7+`subagent-driven-development` + 8 + 9 + 10 + 11 | M's set + `writing-plans` (Stage 4) + `subagent-driven-development` (Stage 7) |
| XL | All stages + ADR mandatory in Stage 3 + memory-keeper double-pass | L's set |

*Stage 4 only if UI; Stage 5 only if open unknowns. **V1 is doc-enforced** — `commands/ship.md` tells the orchestrator to invoke the named Skill at each gate; trust-but-verify. V2 (Phase 8.1, deferred) will add hook-based enforcement via extending `ship-phase-gate.sh` to check Skill tool_use invocation before allowing next Agent dispatch.

**Why this design:** Phase 7.7c /system-retro dogfood showed `/ship` scoring 3.5 on incremental + mode-fit vs superpowers' 5.0 (n=2 each, small sample but architectural finding is independent: /ship's flat 11-stage pipeline was overkill for small asks AND didn't enforce the disciplines superpowers brings). Phase 8.0 collapses small asks to minimal stages while binding the same disciplines explicitly. Will validate via re-run of /system-retro after a few Phase-8 ships.

**Kill:** `SHIP_SCOPE=off` (classifier only, defaults to M). 5 unit tests at `~/.claude/test/ship-scope-classify/` covering kill switch, mocked-Haiku round-trip, soft-fail on bad output, invalid-scope rejection, empty-input fast path.

### `/bake-off` tournament framework (Phase 7.3, 2026-05-20)

`/bake-off [--yolo|--control] "query"` — tournament-tests N skills on the same task. Three modes:

- **default** (blind3): 3 parallel candidates from prefilter (✨-untried weighted), blind A/B/C, AskUserQuestion vote, reveal mapping
- `--yolo`: 1 random skill with <3 bake-off appearances from prefilter top 30 (fallback: random from top 30). Self-rate worked/partial/nope/skip.
- `--control`: 1 known-good (highest win-rate, ≥3 appearances) vs 1 yolo, blind A/B vote

Per-run log at `~/.claude/data/bake-off-log.jsonl`; rolling tallies at `~/.claude/data/bake-off-stats.tsv` (skill_name, appearances, wins, losses, last_run_iso). Both written atomically by `scripts/bake-off-record.sh` using mkdir-based locking (POSIX-portable, no `flock` dependency). Phase 7.4 will consume these.

Kill: `BAKEOFF=off`. 8 unit tests at `~/.claude/test/bake-off/` (34 assertions total).

**Phase 7.4 (2026-05-21):** Auto-elimination filter active across all 3 modes. Skills with `≥3 appearances AND 0 wins` are filtered out of `blind3` selection (both untried and tried tiers), `yolo1` random pick (with eliminated-aware fallback), and `control2` yolo half + known-good fallback. `appearances_of` extracted into `scripts/bake-off-lib.sh` shared with `skills-prefilter.sh`. Kill switch: `BAKEOFF_ELIMINATE=off`. New test `test/bake-off/08-eliminated-dropped.sh` validates end-to-end pipeline integration (3 assertions, blind3/yolo1/control2 deterministic). bake-off-prefilter's own filter is defense-in-depth (skills-prefilter drops eliminated skills first) — covered by code review + lib unit tests rather than per-mode stochastic integration tests (which would add 10+ minutes to the suite due to skills-prefilter I/O cost).

## Hooks (enforced automatically)

| Hook | Event | What it does |
|------|-------|-------------|
| session-retrospective.sh | Stop | **8-check DoD enforcement** — blocks exit if incomplete. Check 8 (NEW 2026-05-20): synthesis cadence — blocks when ≥10 new feedback files since newest `learned/*.md` OR ≥7 days. Kill (whole hook): `RETROSPECTIVE_GATE=off`. Kill (CHECK 8 only): `SYNTHESIS_GATE=off` |
| carl-loader.sh | UserPromptSubmit | Injects CARL domain rules |
| observe-learning.sh | Pre/PostToolUse | Logs activity, increments counter, rotates at 5MB |
| synthesize-learnings.sh | SessionStart | Flags unprocessed feedback for learned/ synthesis |
| check-model-freshness.sh | SessionStart | Warns if model refs >90 days stale |
| surface-hook-blocks.sh | SessionStart | NEW 2026-05-20 — reads `~/.claude/logs/hook-blocks.log`, emits systemMessage if any blocks in last 24h. Kill: `SURFACE_HOOK_BLOCKS=off` |
| content-qa-guarded.sh | PostToolUse:Write\|Edit | PM jargon, tool mentions, 47, handle (content files only) |
| agent-batch-validator.sh | PreToolUse:Agent | Enforces ≤6 operational file path refs AND scope-fidelity (restate full scope when user prompt has scope tokens). Kill (file-count check): `BATCH_GATE=off`. Kill (scope-fidelity check): `SCOPE_GATE=off` |
| inject-skills-for-agent.sh | PreToolUse:Agent | NEW 2026-05-21 — runs `scripts/skills-prefilter.sh` on dispatch description, injects top-3 candidate skills into prompt via `hookSpecificOutput.updatedInput.prompt` for 7 implementation subagents (engineer, designer, debugger, content-social/longform/business, tech-researcher). Phase 7.5.1 (2026-05-21) wrapped block in `<!-- phase-7-5-injected-skills v1 -->` markers for Phase 7.6 detection. Soft-fails open. Log: `~/.claude/logs/inject-skills-for-agent.log`. Kill: `SKILL_INJECT_FOR_AGENT=off` |
| agent-eval.sh --enqueue | PostToolUse:Agent | NEW 2026-05-21 — Phase 7.6 enqueue mode. When Phase 7.5.1 marker present in `tool_input.prompt`, atomically snapshots (task + injected_skills + agent_return) to `~/.claude/data/agent-eval-queue/<ts>-<uuid>.json` for the LLM-judge drain. Soft-fails open on every error path. Log: `~/.claude/logs/agent-eval.log`. Kill: `AGENT_EVAL=off` |
| agent-eval.sh --drain | Stop (after session-retrospective.sh) | NEW 2026-05-21 — Phase 7.6 drain mode. Processes queue via `claude -p --model claude-haiku-4-5-20251001`, jq-validates response with retry-once-on-bad-JSON, appends judgments to `~/.claude/data/agent-eval.jsonl`. Caps: 20 files / 300s per drain, 30s per eval. `timeout`/`gtimeout`/bare fallback for macOS. Kill: `AGENT_EVAL_DRAIN=off` (collect snapshots without spending tokens) or `AGENT_EVAL=off` (full) |
| workflow-gate.sh | PreToolUse:Agent | Gates product-lead-no-brainstorm + engineer-no-tests dispatches. Default-allow + positive-evidence-to-block (uses `subagent_type` or anchored description). Kill: `WORKFLOW_GATE=off` |
| block-dangerous.sh | PreToolUse:Bash | Blocks `rm -rf /`, force-push to main, etc. Kill: `DANGEROUS_GATE=off` |
| block-issue-close-without-tests.sh | PreToolUse:Bash | Blocks `gh issue close` without test/verified evidence. Kill: `ISSUE_CLOSE_GATE=off` |
| caption-guard.sh | PreToolUse:Bash | Blocks freehand SQL caption writes that bypass caption-generator prompt. Kill: `CAPTION_GATE=off` |
| caption-pipeline-guard.sh | PreToolUse:Write\|Edit | Blocks writes to `unstuck/captions/**` without first reading caption-generator.md. Kill: `CAPTION_PIPE_GATE=off` |
| pre-commit-checks.sh | PreToolUse:Bash | Pre-commit lint + missing-tests + remote-ahead check on `git commit`. Kill: `PRECOMMIT_GATE=off` |
| ship-phase-gate.sh | PostToolUse:Agent\|Bash | Gates /ship Stage 9 (Deploy + Smoke). 3-deploy rule, observability check, smoke check. Activates only when `.ship/<run>/patterns.md` is present. Kill: `SHIP_PHASE_GATE=off` |
| archetype-injector.sh | UserPromptSubmit | reads cwd + prompt, resolves archetype from projects.yaml, emits (1) relevant learned/ pattern names, (2) Phase 7.1.5 detected work-type chain (build/plan/review/debug/research/write-content/memory/design/infra — first-match regex on prompt, ordered chain from `~/.claude/work-type-chains.yaml`), (3) Phase 7.1 archetype-relevant skill names from `~/.claude/skill-archetypes.yaml`, all with 60-char taglines. Caches per-cwd (work-type bypasses cache, runs every turn). Kill (whole hook): `ARCHETYPE_GATE=off`. Kill (skill block only): `SKILL_INJECTION=off`. Kill (work-type block only): `WORKTYPE_GATE=off` |

All PreToolUse + Stop hooks call `~/.claude/hooks/lib/log-block.sh` `log_block()` before blocking — appends NDJSON entry to `~/.claude/logs/hook-blocks.log` for cross-session triage via `surface-hook-blocks.sh`.

### Hook wire-in (manual, fresh installs)

`settings.json` is gitignored in the claude-config repo (contains personal paths, MCP URLs). For a fresh install, see `settings.example.json` + `settings.example.README.md` in the repo root for the structural skeleton plus manual wire-in steps.

## Plugins (enabled in settings.json)

**Core:** superpowers, commit-commands, context7, typescript-lsp, playwright, supabase
**Engineering:** compound-engineering, code-review, pr-review-toolkit, code-simplifier, everything-claude-code
**Security:** audit-context-building (trailofbits), differential-review (trailofbits), ask-questions-if-underspecified (trailofbits)
**Design:** frontend-design, ui-ux-pro-max

## MCP Integrations

Connected (read auto-approved, writes need confirmation):
Gmail, Google Calendar, Notion, Canva, Playwright, Context7, Firecrawl.

## Memory System

Persistent at `~/.claude/projects/<your-workspace>/memory/`:
- `MEMORY.md` — index (loaded every session)
- Individual files by type: user, feedback, project, reference
- Feedback files auto-checked against `learned/` by synthesize-learnings.sh
- **v2 frontmatter schema** (added 2026-05-10) on `learned/` + `memory/` files: `name`, `description`, `type`, `applies-to: [tags]`, `projects: [names|all]`, `severity: blocking|warning|info`, `phase: [stages]`, `last-validated`. Validated by `~/.claude/scripts/validate-frontmatter.sh`.
- **memory-keeper agent** loads filtered set into `.ship/<run>/patterns.md` at /ship pre-flight; captures new feedback at post-flight.
- See `docs/ship-pipeline-v2.md` for the full pipeline + tag vocabulary.

## Layered Memory (Phase 5.1 complete 2026-05-19 — 3 new project wings + canonical rooms across 17 yamls; auto-mine LIVE on Stop+PreCompact)

Memory lives in three layers — each loaded a different way, each holds a different shape of knowledge. **As of Phase 4, per-project memory dirs are WRITE-ONLY** (capture target; auto-mined to MemPalace; never read directly). **As of Phase 5, the palace has a canonical 22-wing taxonomy** (14 project + 7 infrastructure + 1 sessions). 17 `mempalace.yaml` files use a canonical 5-room template (`general`/`decisions`/`problems`/`planning`/`technical`). Idempotency caveat: existing drawers stay in their original rooms; new captures route to canonical rooms.

> The private config uses [MemPalace](https://github.com/molly-diversifiedfun/mempalace) for the long-tail memory layer. This public snapshot describes the integration shape (write-only project dirs, auto-mine on Stop hook, MCP-only read path) so you can wire your own equivalent. The `mempalace-wrapper.sh` hook soft-fails open if mempalace is missing — so this snapshot installs cleanly without it.

| Layer | Location | When loaded | What lives there |
|---|---|---|---|
| **Always-on** | `~/.claude/skills/learned/` + this CLAUDE.md + CARL rules | System prompt — every turn | 22 distilled cross-project patterns (blocking corrections); base instructions; CARL domains |
| **Passive recall** | `~/.mempalace/identity.txt` + L1 wake-up | SessionStart hook injects ~800 tokens once per session | your identity profile; top-priority recent/relevant drawers — "the gist" |
| **Retrieval on demand** | MemPalace palace via `mcp__mempalace__*` MCP tools | Queried when relevant | All 95k+ drawers (memory files, session transcripts, project content) — searchable by semantic + keyword + wing/room filters. **SOLE READ PATH for long-tail context.** Agents/commands wired with pre-flight (Phases 2 + 3). Per-project memory dirs (`~/.claude/projects/*/memory/`) are WRITE targets only — never read directly. |

### When to query MemPalace mid-session

Call `mcp__mempalace__mempalace_search` (or `mempalace search` via Bash) when the prompt mentions:
- A project name (<your-personal-ai-project>, <your-agent-project>, <your-project-1>, marketing-os, ship-it-system, etc.) → narrow with `wing` filter
- Recall signals: "remember when", "previously", "have we", "did we discuss", "what do I know about", "background on"
- Recipe names: Gumroad, Telegram, Supabase, n8n, Notion, Vercel, Railway, PostHog
- Conflict signals: "but didn't we decide X?", "I thought we said Y"
- Cross-project pattern hunting: "have I solved this before?"

Default: if a non-trivial task references a specific project, query MemPalace for that wing first. Skip for trivial questions (typos, single-line fixes).

### Auto-save (write side, always on)

- **Stop hook** (`mempalace-wrapper.sh --hook=stop`): saves session every 15 human messages + **auto-mines all 14 memory dirs with `mempalace.yaml`** (Phase 5, workspace-github first, serial, 20s cap)
- **PreCompact hook** (matcher `Compact` under `PreToolUse`): emergency save + auto-mine before context loss
- **SessionStart hook** (`mempalace-wrapper.sh --hook=session-start`): injects wake-up (NO auto-mine — too slow at session start)

Hook wrapper at `~/.claude/hooks/mempalace-wrapper.sh` soft-fails open (exit 0 + `{}`) if mempalace is missing or hangs — the palace can break without breaking the harness. Audit trail at `~/.claude/logs/mempalace-hooks.log`.

**R7 caveat:** the Stop hook's `_wing_from_transcript_path()` still seeds `wing_<token>` wings from session transcripts (Phase 6.5 work). Expect 1-3 `wing_*` wings to recur between cleanups. Canonical wings always win — query without filter if wing-filter fails.

### Status of the old memory system (Phase 4 complete)

- **`~/.claude/skills/learned/`** — STILL the always-on layer. Read every turn via system prompt + Glob in agents. No change.
- **`MEMORY.md`** — pruned to TOC index only. Lives at `~/.claude/projects/<your-workspace>/memory/MEMORY.md`. New entries STILL append here as a pointer index. Loaded into session context every turn.
- **`~/.claude/projects/*/memory/*.md`** — **WRITE-ONLY as of Phase 4 (2026-05-19).** Stage 11 captures land here; Stop hook auto-mines to MemPalace; agents/commands NEVER read these directly. The files stay on disk as backup + archaeological reference. To READ memory content, always query MemPalace.
- **MemPalace** — sole read path for the long-tail layer. 95k+ drawers searchable via MCP. Pre-flight wired into all 13 working agents (Phase 2) + 11 slash commands (Phase 3) + CARL MEMORY domain (Phase 2).

If MemPalace is unhealthy and the long-tail layer is unreadable, agents raise BLOCKED rather than falling back to file Glob (which would reintroduce stale on-disk content as authoritative).

# Your Preferences (customize this section)

The original private config carried personal preferences for communication style, writing voice, language choices, and tech-stack defaults. They were stripped from this public snapshot — replace with your own. Below are the **non-personal** discipline rules that the rest of this config depends on. Keep these or they'll silently misfire.

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
- DoD enforced by session-retrospective.sh (8 checks including synthesis cadence, blocks session end).
- See `rules/common/definition-of-done.md` for full checklist + doc mapping.
- "Major milestone" = committed feature, architectural decision, or resolved bug a future session needs.
