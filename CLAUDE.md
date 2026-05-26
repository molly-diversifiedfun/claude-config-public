# Claude Code Configuration

## Product Team — ALWAYS Delegate

Agents are defined in `~/.claude/agent-skill-manifest.yaml` (single source of truth, Phase 8.x). Generated agent.md files live in `~/.claude/agents/` (regenerated, do not hand-edit). Human-readable directory at `~/.claude/docs/skill-directory.md`.

**Roster (12 agents):**
- **Pipeline owners (5):** builder, creator, strategist, researcher, operator
- **Utility specialists (7):** product-lead, designer, debugger, security, reviewer, content-qa, memory-keeper

**Deprecation aliases (Phase 8.x.4 — old names now resolve to the real agent via body injection):**
- `engineer` → `builder`
- `content-social` / `content-longform` / `content-business` → `creator`
- `tech-researcher` / `market-researcher` → `researcher`
- `project-manager` → `operator`

These old names are NOT registered subagents, but the `inject-skills-for-agent.sh` hook intercepts them and injects the **full agent body** of the correct new agent via `updatedInput.prompt`. The dispatched general-purpose agent receives the complete role definition, JTBDs, skills, and notes — so it behaves as the target agent. Not as clean as a real frontmatter load (no tool/skill grants from frontmatter), but far better than running generic. Verified by probe: `engineer` reports builder's 9 JTBDs; `project-manager` reports operator's 6 slash commands. `updatedInput.subagent_type` was tested and crashes the harness — prompt injection is the only viable lever. Using the new name directly is still preferred (gets the real frontmatter-driven load).

To add/modify an agent: edit `~/.claude/agent-skill-manifest.yaml`, run `python3 ~/.claude/scripts/render-manifest.py`, validate via `bash ~/.claude/scripts/validate-manifest.sh`. The pre-commit hook + Stop drift hook keep the generated files honest.

See `~/.claude/docs/skill-directory.md` for JTBD → agent mapping and `~/.claude/docs/agent-skill-gap-analysis.md` for design rationale.

Previous 14-agent roster archived at `~/.claude/agents-v1-archive.tar.gz` (Phase 8.x Task 9 complete).

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

## CARL Rule System (Simplified 2026-05-26)

CARL domain rules migrated to learned patterns. Only **star-commands** remain (`*dev`, `*review`, `*brief`, `*plan`, `*discuss`, `*debug`, `*explain`). The `carl-loader.sh` hook now only parses star-commands from the prompt — no domain keyword matching, no always-on rule injection.

Previous 11 domains (130 rules) archived at `~/.carl/domains-archive-2026-05-26.tar.gz`. ~110 rules were redundant with existing learned patterns; ~25 unique rules migrated to 7 new learned patterns: `plan-artifact-discipline`, `plan-pipeline-gates`, `check-before-create`, `present-labeled-options`, `context-brackets`, `n8n-build-patterns`, `design-color-discipline`.

## Skill Collections

Custom skills (in `~/.claude/skills/`):
- **Learned patterns:** `learned/` — ~44 cross-project pattern files (5 blocking, rest warning). Frontmatter schema: `name`, `description`, `severity`, `archetypes`, `last-validated`. Loaded every session by `archetype-injector.sh` (blocking always-on, others filtered by project archetype).
- **Brand voice:** `brand-voice-router/` — all 3 brands + you Direct, with plugin integration. Partial-read: `scripts/brand-voice-extract.sh <brand>` outputs preamble + one brand (saves 22-48% vs full file).
- **Writing:** `humanize-ai-writing/`, `voice-extractor/`
- **Thinking:** `mental-models/`, `devils-advocate/`, `decision-maker/`, `self-interview/`, `ask-me-the-questions/`
- **Content:** `brainstorm/`, `code-documenter/`, `handoff/`
- **Dev tools:** `carl-manager/`, `carl-help/`, `nano-banana/`, `firecrawl/`

External (not auto-discovered):
- Writing books: `~/github/claude-code-toolkit/skills/non-fiction-book-factory/`
- Writing ebooks: `~/github/claude-code-toolkit/skills/ebook-factory/`
- Writing craft: `~/github/claude-code-toolkit/skills/writing/`

### Historical phases (7.x–8.x) — reference only

The sections below document the evolution of skills, consolidation, bake-off, and /ship tooling. agent-eval (Phase 7.6) was **disabled 2026-05-26** (5 total evals, low signal; `AGENT_EVAL=off`). CARL domain injection (referenced in Phase 7.5) was **removed 2026-05-26** (migrated to learned patterns). The tooling itself (/skills, /consolidate-skills, /bake-off, /ship, /system-retro) is still functional.

### `/skills` semantic catalog (Phase 7.2, 2026-05-20; 7.2.2 patch 2026-05-21)

`/skills "what you want to do"` — semantic search over ~600 installed skills. `scripts/skills-prefilter.sh` pre-filters by archetype + keyword grep (≤30 candidates, 3 priority tiers: Pool1∩Pool2 → Pool2 only → Pool1 only), then the parent Claude turn ranks the top 5 with rationale. Reuses `skill-archetypes.yaml` from Phase 7.1. Kill: `SKILLS_CATALOG=off`. No args → usage hint. 10 unit tests at `test/skills/`.

**Phase 7.2.2 (2026-05-21):** Pool 2 membership now requires a description-line keyword match (score ≥ 1), not just a whole-file body grep. Whole-file grep stays as a cheap prefilter, but body-only matches (where a keyword appears in examples / triggers / instructions but the description has nothing relevant) are dropped before tier sort. Eliminates the bug where score=0 always-on skills crowded Tier A and pushed semantic matches in Tier C below them via alphabetical tiebreak (`ask-me-the-questions` winning slot 1 over `humanize-ai-writing` for humanize queries). Candidate count for typical queries drops ~5-10× (e.g. 202 → 37 for "humanize this paragraph"). Test 07 covers regression.

**Phase 7.4 (2026-05-21):** `/skills` output now consumes per-skill stats from `~/.claude/data/bake-off-stats.tsv` via shared helpers in `scripts/bake-off-lib.sh`. Two new behaviors: (1) skills with `≥3 bake-off appearances AND 0 wins` are dropped from the candidate list entirely (kill switch: `BAKEOFF_ELIMINATE=off`); (2) skills with `<3 appearances` get a column-4 `untried` flag, rendered as `✨` prefix in the top-5 display to drive bake-off adoption on under-tested skills. Tests 08-09 cover both behaviors using `mktemp -d` + `BAKEOFF_STATS_FILE` env-var override (per `feedback_test_fixtures_must_not_write_live_data_files.md`).

**Phase 7.2.3 (2026-05-21):** Two scoring-quality calibrations from `feedback_phase_7_2_2_residual_calibration_targets.md`. (1) `STOPWORDS` extended with five high-frequency low-signal generics from corpus analysis (`use`=52% of descriptions, `skill`=19% self-reference, `any`/`should`/`before` ~8% each). (2) Description-match stemming tightened from `\b<kw>` (unbounded prefix) to `\b<kw>(s|es|d|ed|ing)?\b` (controlled regular-suffix stems with trailing word boundary). Eliminates the false-positive class where `\bmake` matched `decision-maker` inside descriptions. Real writing skills (`copywriting`, `docs:write-concisely`) now surface in top 5-7 for humanize queries instead of being displaced by alphabetical noise. Test 10 covers both calibrations; full prefilter suite 10/10.

**Phase 7.5 (2026-05-21) → SUPERSEDED by Phase 8.x.4 (2026-05-25).** Original: skill-injection prefilter for 7 allowlisted subagents. Phase 8.x.3 scoped the allowlist to deprecated aliases only (real manifest agents load natively). **Phase 8.x.4 replaced the entire skill-injection path** with full-agent-body injection: when a deprecated alias fires, the hook reads the target agent's `.md` body and injects it via `updatedInput.prompt`. No prefilter, no skill candidates — the dispatched agent receives the complete role definition. `updatedInput.subagent_type` was tested and crashes the harness (not a supported field). Commit `5fc6afd`. Log: `~/.claude/logs/inject-skills-for-agent.log`. Kill: `SKILL_INJECT_FOR_AGENT=off`.

**Phase 7.5.1 (2026-05-21):** ~~Wraps the Phase 7.5 injection block in stable HTML-comment markers~~ — markers are no longer emitted (Phase 8.x.4 replaced the injection format). The Phase 7.6 agent-eval enqueue hook still checks for the old markers; it will fire only on sessions that still have the old-format dispatches in their context. No functional impact.

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

**Slug-encoding finding:** Claude Code's transcript dir slugs map both `/` AND `.` to `-` (so `$HOME/github/nancy` → `<your-workspace>-nancy`). Reverse-parsing the slug is fundamentally lossy (`molly.shelestak` and `molly-shelestak` are indistinguishable post-encoding). Solved by forward-built index: walk likely cwd roots (`~`, `~/github`, `~/Desktop`, `~/Downloads`, `~/.claude`, `/private/tmp`, `/tmp`) two-deep, compute each real dir's slug, build `dict[slug, str(real_path)]`. Regression test at `test/system-retro/08-cwd-slug-roundtrip.sh`.

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

### `classify-scope.sh` manifest-dispatch classifier (Phase 8.x.1, 2026-05-25)

`~/.claude/scripts/classify-scope.sh --prompt "<text>" --jtbd-default <S|M|L|XL>` — deterministic scope classifier for the agent-skill manifest dispatch layer. Emits one of `S|M|L|XL` to stdout. Implements spec OQ7 "manifest wins on low confidence" precedence: a confident prompt-keyword hit (S signals like `typo`, `env var`, `rename …`, `dep bump`, one-liner; XL signals like `architectural`, `new service`, `rewrite`, `framework swap`) overrides the JTBD's declared `default_scope`; otherwise the declared default wins. No LLM call — pure regex on a lowercased copy of the prompt, keeps the dispatch path zero-cost and side-effect-free. Soft-fails to `--jtbd-default` on empty prompt. Kill switch: `CLASSIFY_SCOPE=off` → always echoes the declared default. Bad `--jtbd-default` value exits 2 (negative-test enforced).

Turns Phase 8.x manifest-dispatch tests 05+06 GREEN (was 4/6, now 6/6). Smoke: downward override (`fix typo` + L → S), upward override (`add a new service` + S → XL), no-signal cases preserve declared default (`ship the analytics dashboard` + L → L), empty prompt returns default, kill switch returns default unchanged. Mirror of script lives in `~/github/claude-config/scripts/`.

### `render-manifest.py` canonical output format (Phase 8.x.2, 2026-05-25)

Fix for the Phase 8.x dogfood Scenario 4 finding (`feedback_phase_8x_agents_dir_not_enumerated.md`): pre-canonical `render-manifest.py` emitted nested `tools.built_in` + `skills.primary` blocks plus invented frontmatter fields (`kind`, `owns_jtbd`, `owns_slash_commands`, `can_invoke_specialists`) which Claude Code's subagent loader silently rejects. Result: all 12 user-level agents were unregistered. Dispatches to non-allowlisted names (`strategist`, `operator`) hard-failed with "Agent type not found"; dispatches to allowlisted names (`creator`, `researcher`, `builder`, `designer`, `debugger`) only "worked" because the Phase 7.5 PreToolUse hook back-doored them via `updatedInput.prompt` mutation — verified by a builder probe that returned `agent_name_in_system_prompt: Claude Code`, not `builder`.

New output emits the canonical fields per https://code.claude.com/docs/en/sub-agents: `name`, `description`, `model`, `tools` (comma-separated string, built-in tools only), `skills` (block list of primary skills only). All other manifest metadata moves to the markdown body so the agent's system prompt still knows what it owns: `## Owns slash commands`, `## Owns JTBDs`, `## Chain skills (on-demand)`, `## MCP servers`, `## Can invoke specialists`, `## Notes`. No frontmatter field in the new output is outside the documented 15-field allowlist.

Tests: all 3 suites GREEN (render-manifest 6/6, manifest 10/10, manifest-dispatch 6/6). validate-manifest.sh against real manifest: 13/13 OK. Goldens at `~/.claude/test/manifest/fixtures/golden/{builder,product-lead}.md` regenerated. Test 03 (`03-chain-skills-section.sh`) updated to grep for chain skills in the body (`## Chain skills` heading + `- humanize-ai-writing` bullet) instead of the old nested-YAML `^  chain:` block. Shipped as commit `7d1144b` in `~/github/claude-config/`.

**Verify after restart:** dispatch `subagent_type=strategist` with a single-roundtrip probe asking the subagent to read its own system prompt. Success = `name: strategist` (manifest agent loaded). Failure = `Claude Code` (still unregistered, fix didn't land). Output-shape conformance is not verification — a capable general-purpose imitates any agent given a prescriptive prompt; the system prompt's own name is the signal.

### `render-manifest.py` frontmatter-at-byte-0 fix (Phase 8.x.3, 2026-05-25)

The 2026-05-25 restart probe ran and **failed differently than predicted**: `subagent_type=strategist` returned "Agent type 'strategist' not found" — all 12 manifest agents were absent from the dispatch roster entirely (not the predicted `name: Claude Code` back-door case). Root cause: Phase 8.x.2 fixed the frontmatter *fields* but `render_agent()` still emitted the `<!-- DO NOT EDIT -->` HEADER on **line 1, above the opening `---`**. Claude Code's subagent loader requires YAML frontmatter at **byte 0**; a leading HTML comment means no frontmatter is found and the agent is silently dropped. Decisive evidence: loading plugin agents (e.g. `everything-claude-code/agents/planner.md`) start with `---\n` at byte 0; ours started with `<!-- D`.

Fix: `render_agent()` now builds `lines = ["---", ...]` and appends `HEADER` as the **first body line** (after the closing `---`). Files start with `---` at byte 0; the do-not-edit notice survives as an in-body HTML comment (invisible in rendered markdown). `validate-manifest.py` unaffected (whole-file `DRIFT_HEADER in content` substring, not line 1). Both `render-manifest.py` copies (`~/.claude/scripts/` + `~/github/claude-config/scripts/`) synced identical. Test 05 (`05-every-output-has-header.sh`) rewritten to assert line-1 == `---` plus HEADER-present-in-body. All 12 live agents regenerated + 2 goldens regenerated. Suites green (render-manifest 6/6, manifest 10/10, manifest-dispatch 6/6); validate-manifest.sh 13/13.

**CONFIRMED 2026-05-25 via fresh-subprocess probe (no restart needed).** The interactive session's Agent roster is frozen at startup, but a fresh `claude -p` subprocess re-scans `~/.claude/agents/` live. Probe: `cd /tmp && claude -p "Call the Task tool once with subagent_type='__probe_nonexistent__' ... output the verbatim error" --allowedTools Task --output-format text` — the harness validates the bogus type and echoes the freshly-computed available-agents list (cheap; no real agent runs). Result: the list now includes all 12 manifest agents (builder, content-qa, creator, debugger, designer, memory-keeper, operator, product-lead, researcher, reviewer, security, **strategist**). This proves the harness DOES enumerate `~/.claude/agents/` — **revising** the prior `feedback_phase_8x_agents_dir_not_enumerated` conclusion (which mistook "all 12 files malformed" for "harness ignores the dir"). Agents are live for any newly-started session. **Reusable technique:** to verify `~/.claude/agents/` changes mid-session without restarting, run the fresh-subprocess bogus-dispatch probe above and grep the roster.

**Byte-0 was necessary but NOT sufficient — a SECOND bug.** Body-content probes (role + owned-slash-commands, not name) revealed 5 of the 12 agents still ran generic: `builder`, `creator`, `designer`, `debugger`, `researcher`. Cause: the Phase 7.5 `inject-skills-for-agent.sh` hook allowlisted exactly those names and emitted `updatedInput.prompt` on their `PreToolUse:Agent` dispatch — which **hijacks** the dispatch into a generic run instead of loading the (now-working) agent body. The hook predates the byte-0 fix and is redundant now that agents declare `skills:` in frontmatter. Fix: scoped the hook's allowlist down to deprecated aliases only (`engineer|content-social|content-longform|content-business|tech-researcher`); the 5 manifest names dropped out and load natively. Verified: `builder` with the hook ON now reports `role: pipeline owner… / owns: /plan /build /ship /fix`. The other 7 agents (strategist, operator, product-lead, reviewer, security, content-qa, memory-keeper) were never allowlisted and always loaded correctly. Full proof chain: `feedback_phase_7_5_hook_hijacks_manifest_agents`. **Lesson:** probe dispatch by BODY-unique content via a fresh `claude -p`, never by self-reported name (base identity reads "Claude Code" regardless); and when you fix a root cause, audit the hooks that compensated for it.

### `/bake-off` tournament framework (Phase 7.3, 2026-05-20)

`/bake-off [--yolo|--control] "query"` — tournament-tests N skills on the same task. Three modes:

- **default** (blind3): 3 parallel candidates from prefilter (✨-untried weighted), blind A/B/C, AskUserQuestion vote, reveal mapping
- `--yolo`: 1 random skill with <3 bake-off appearances from prefilter top 30 (fallback: random from top 30). Self-rate worked/partial/nope/skip.
- `--control`: 1 known-good (highest win-rate, ≥3 appearances) vs 1 yolo, blind A/B vote

Per-run log at `~/.claude/data/bake-off-log.jsonl`; rolling tallies at `~/.claude/data/bake-off-stats.tsv` (skill_name, appearances, wins, losses, last_run_iso). Both written atomically by `scripts/bake-off-record.sh` using mkdir-based locking (POSIX-portable, no `flock` dependency). Phase 7.4 will consume these.

Kill: `BAKEOFF=off`. 8 unit tests at `~/.claude/test/bake-off/` (34 assertions total).

**Phase 7.4 (2026-05-21):** Auto-elimination filter active across all 3 modes. Skills with `≥3 appearances AND 0 wins` are filtered out of `blind3` selection (both untried and tried tiers), `yolo1` random pick (with eliminated-aware fallback), and `control2` yolo half + known-good fallback. `appearances_of` extracted into `scripts/bake-off-lib.sh` shared with `skills-prefilter.sh`. Kill switch: `BAKEOFF_ELIMINATE=off`. New test `test/bake-off/08-eliminated-dropped.sh` validates end-to-end pipeline integration (3 assertions, blind3/yolo1/control2 deterministic). bake-off-prefilter's own filter is defense-in-depth (skills-prefilter drops eliminated skills first) — covered by code review + lib unit tests rather than per-mode stochastic integration tests (which would add 10+ minutes to the suite due to skills-prefilter I/O cost).

## Hooks (enforced automatically — simplified 2026-05-26)

| Hook | Event | What it does |
|------|-------|-------------|
| carl-loader.sh | UserPromptSubmit | Star-commands only (*dev, *review, etc.). Domain rules removed. |
| archetype-injector.sh | UserPromptSubmit | Resolves archetype from projects.yaml, injects relevant learned patterns (blocking + archetype-filtered). No skill/work-type injection. Kill: `ARCHETYPE_GATE=off` |
| mid-session-dod-nudge.sh | UserPromptSubmit | Soft nudge if >100 tool calls + stale HANDOFF.md. Once per day. Kill: `MID_SESSION_NUDGE=off` |
| observe-learning.sh | PostToolUse | Increments tool counter only (no JSONL logging). Feeds mid-session nudge. |
| block-dangerous.sh | PreToolUse:Bash | Blocks `rm -rf /`, force-push to main, curl\|sh. Kill: `DANGEROUS_GATE=off` |
| pre-commit-checks.sh | PreToolUse:Bash | Pre-commit lint + missing-tests + remote-ahead. Kill: `PRECOMMIT_GATE=off` |
| pre-commit-validate-manifest.sh | PreToolUse:Bash | Agent manifest validation on staged manifest/agent commits. Kill: `MANIFEST_GATE=off` |
| block-issue-close-without-tests.sh | PreToolUse:Bash | Blocks `gh issue close` without test evidence. Kill: `ISSUE_CLOSE_GATE=off` |
| caption-guard-unified.sh | PreToolUse:Bash+Write\|Edit | Blocks freehand SQL caption writes AND caption file edits without prompt read. Kill: `CAPTION_GATE=off` |
| workflow-gate.sh | PreToolUse:Agent | Gates product-lead-no-brainstorm + engineer-no-tests. Kill: `WORKFLOW_GATE=off` |
| agent-batch-validator.sh | PreToolUse:Agent | Enforces ≤6 file refs + scope-fidelity. Kill: `BATCH_GATE=off` / `SCOPE_GATE=off` |
| inject-skills-for-agent.sh | PreToolUse:Agent | Deprecated alias → agent body injection. Real manifest agents untouched. Kill: `SKILL_INJECT_FOR_AGENT=off` |
| content-qa-guarded.sh | PostToolUse:Write\|Edit | PM jargon, tool mentions, 47, handle check on content files. |
| prettier-format.sh | PostToolUse:Write\|Edit | Auto-format on write. |
| ship-phase-gate.sh | PostToolUse:Agent\|Bash | 3-deploy rule, observability, smoke check. Only when /ship active. Kill: `SHIP_PHASE_GATE=off` |
| session-end-save.sh | Stop | Backs up HANDOFF.md + TASKS.md (rate-limited 10min/project, 3-day retention). |
| session-retrospective.sh | Stop | DoD enforcement with grace: 1st miss = soft nudge, 2+ consecutive = hard block. Checks HANDOFF.md + TASKS.md freshness only (8 checks trimmed to 2). Kill: `RETROSPECTIVE_GATE=off` |
| stop-check-manifest-drift.sh | Stop | Logs agent manifest drift. Never blocks. Kill: `MANIFEST_DRIFT_CHECK=off` |
| mempalace-wrapper.sh | SessionStart+Stop+Compact | MemPalace session save, auto-mine, wake-up injection. 10s timeout. |
| synthesize-learnings.sh | SessionStart | Flags unprocessed feedback for learned/ synthesis. |
| teammate-idle-gate.sh | TeammateIdle | Blocks if teammate says work is unfinished. Kill: `TEAMMATE_IDLE_GATE=off` |
| task-complete-gate.sh | TaskCompleted | Blocks literal "Run X" commands without execution evidence. Kill: `TASK_COMPLETE_GATE=off` |
| auto-approve.sh | PermissionRequest | Auto-allows reads, blocks git push + deploys + external writes. |

Full kill switch reference: `~/.claude/hooks/KILL_SWITCHES.md`

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

Memory lives in three layers — each loaded a different way, each holds a different shape of knowledge. **As of Phase 4, per-project memory dirs are WRITE-ONLY** (capture target; auto-mined to MemPalace; never read directly). **As of Phase 5, the palace has a canonical 22-wing taxonomy** (14 project + 7 infrastructure + 1 sessions) — see `~/github/docs/mempalace-wings.md` for the source of truth. **As of Phase 5.1, wing count = 30** (Phase 5 baseline 26 + 3 new project wings: `mollyshelestak`, `giftshopper`, `joelaumakua` from Item 2 + 1 R7-recreated `wing_github`); 17 mempalace.yaml files now use the canonical 5-room template (`general`/`decisions`/`problems`/`planning`/`technical`). Idempotency caveat: existing drawers stay in their original rooms; new captures route to canonical rooms. **Phase 5.2 (deferred):** `tmp` wing cleanup + PostHog credential rotation + `/tmp/posthog-auth.json` scrub — still pending, leak window open.

| Layer | Location | When loaded | What lives there |
|---|---|---|---|
| **Always-on** | `~/.claude/skills/learned/` + this CLAUDE.md | System prompt — every turn | ~44 learned patterns (5 blocking, rest archetype-filtered warnings); base instructions |
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

# your Global Preferences

## Communication
- Be direct. Skip preamble.
- Show code/output first, explain if asked.
- Never say "I'd be happy to" or "Great question."
- Use technical terminology — I'm a senior PM with 20+ years in tech.

## Writing
- Never sound like AI wrote it. No corporate filler.
- Content pipeline: brand-voice-router → humanize-ai-writing → content-platform-adapter.
- See `rules/` for coding style, patterns, and conventions.

## Code
- TypeScript strict, functional patterns, composition over inheritance.
- Python for scripting. ReportLab for branded PDFs.
- Test-first when scope is clear.

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
- DoD in `rules/common/definition-of-done.md` — full checklist + doc mapping.
- `session-retrospective.sh` — **re-enabled with grace mechanism** (2026-05-26): 1st miss = soft nudge, 2+ consecutive misses = hard block. Only checks HANDOFF.md + TASKS.md freshness (trimmed from 8 checks to 2). Mid-session nudge (`mid-session-dod-nudge.sh`) provides early soft reminders.
- "Major milestone" = committed feature, architectural decision, or resolved bug a future session needs.

## Config files — what's live vs inert
- `work-type-chains.yaml` — **inert at runtime** since 2026-05-26 (archetype-injector no longer reads it). Still valid config, consumed only by `validate-work-type-chains.sh`. Could be re-activated at agent dispatch time if needed.
- `skill-archetypes.yaml` — **live**, consumed by `/skills` command prefilter (`scripts/skills-prefilter.sh`). Maps skill names to archetypes for Pool 1 filtering.
- `projects.yaml` — **live**, consumed by archetype-injector for cwd → archetype resolution.
- "Major milestone" = committed feature, architectural decision, or resolved bug a future session needs.
