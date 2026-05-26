# Learned Patterns

Cross-project learnings synthesized from session feedback. 28 patterns extracted from 200+ memory files across 11 projects, representing corrections you has made repeatedly. Two former entries (`competitive-history.md` and `hook-performance.md`) were moved to the memory/ directory on 2026-05-12 — they were rolling data, not patterns.

## When to use
Load at session start (CARL WORKFLOW_RULE_10 says "read MEMORY.md index, actively apply feedback memories"). These files are the distilled, actionable version of scattered memory feedback.

## Pattern index

| File | Pattern | Archetypes | Enforcement |
|------|---------|------------|-------------|
| systematic-shortcutting.md | Don't skip steps to go faster (13 variants) | always-on | CARL WORKFLOW_RULE_0 |
| never-fabricate.md | Never invent personal stories/numbers | always-on | CARL GLOBAL_RULE_6 |
| ai-tell-avoidance.md | Kill AI writing tells (47, Notion, vocab) | brand-content, always-on | CARL WRITING + CONTENT-RULES |
| ai-design-tells.md | Kill AI design tells (gradient blobs, symmetric grids, indigo primary, gradient pill CTAs) — visual/component/code sister to ai-tell-avoidance | web-app, brand-content | Pre-merge UI audit (26-point checklist); points to `unstuckwithmolly/docs/ai-design-tells.md` canonical 474-line ref |
| verify-before-commit.md | Read agent output, surface silent failures, ask clear questions | always-on | CARL GLOBAL_RULE_5 |
| delegation-discipline.md | Use the right agent; reuse existing skills before building | always-on | CARL WORKFLOW_RULE_5 |
| voice-and-content-rules.md | Voice register, pillars, format mix, copy is sacred | brand-content | CARL WRITING + CONTENT-RULES |
| documentation-after-build.md | DoD compliance, docs ship with code | always-on | rules/common/definition-of-done.md |
| nonfiction-sourcing.md | Source facts before writing claims | brand-content | CARL WRITING_RULE_5 |
| deploy-iteration-discipline.md | 3-deploy rule, observability, change-set drift, framework abandonment | web-app, telegram-bot, infra-config | (process discipline) |
| secrets-routing.md | Secrets go direct to deploy target; Raw Editor leaks | always-on | CARL RIGOR + rejected-patterns.md |
| n8n-production-patterns.md | n8n hard limits, Apify/Postgres/Meta gotchas, fix coverage upstream | telegram-bot, content-pipeline | (project: content-system) |
| mass-rewrite-mechanics.md | Batch-Read all targets before batch-Write when rewriting ≥3 files | always-on | (tool discipline) |
| task-budget-heuristic.md | Estimate token cost before multi-phase tasks; surface phased options at ~60% | always-on | (context discipline) |
| dogfood-by-using-the-system-to-document-itself.md | First real run of a new system should produce its own docs/release artefact | infra-config | (process discipline) |
| qa-rules.md | 23-item content QA checklist (operational config for @content-qa) | brand-content | (agent config) |
| research-budgets.md | Time + cost ceilings per research type for @market-researcher / @tech-researcher | always-on | (agent config) |
| bot-conversational-ux.md | Cross-bot UX for Telegram products: buttons over free-text, no gating, trust character over rules | telegram-bot | (project: nancy + <your-agent-project> + shipitwithmolly) |
| domain-repo-analytics-mapping.md | Verify domain↔repo↔analytics via Vercel `domains` field BEFORE wiring (brand name lies) | web-app | (pre-flight blocker) |
| hook-design-discipline.md | Calibrate enforcement hooks by blast radius; hard blocks only at narrow boundaries | infra-config | (claude-config process) |
| gumroad-tiptap-editing.md | Use `editor.commands.setContent()` via Playwright on TipTap-based editors (Gumroad, Ghost, etc.) | content-pipeline, brand-content | (tool recipe) |
| audit-trail-before-speculative-fix.md | Instrument before fixing; for LLM agent bugs query the transcript FIRST | always-on | CARL DEBUG (process discipline) |
| git-history-scrub-discipline.md | 5 preconditions + bare --force (not --with-lease) + replacements format for any `git filter-repo` op | infra-config, always-on | (claude-config process) |
| mempalace-discipline.md | Wing-filter fail-open + status check + 3-layer query + bulk-load with gitleaks gate; MemPalace is sole long-tail read path post-Phase 4 | always-on | CARL MEMORY domain |
| scoring-design-discipline.md | Tier-demotion vs noise-floor bypass: in tiered scoring with special per-category rules, make demotion-vs-bypass semantics explicit (default: demotion) | infra-config, content-pipeline | (spec self-review) |
| data-source-of-truth-discipline.md | Append-only log is authoritative; derived cache is recoverable. Document reconstruction path. Pin field semantics. | always-on | (data-design discipline) |
| cli-integration-discipline.md | Pre-build smoke before designing pipeline caps. `claude --bare -p` is mandatory (22× cheaper). Envelope+fence parsing for `--output-format json`. Transcript slugs are lossy — forward-index, never reverse-parse. | infra-config, telegram-bot, content-pipeline | (spec discipline) |
| cross-repo-ci-discipline.md | When canonical source moves between repos, the auto-sync CI follows it. Path-triggered workflows in the old repo go inert silently. Intra-repo regen needs no CI; cross-repo needs a fine-grained PAT on the canonical repo. | infra-config, multi-product, build-pipeline | (architecture discipline) |

## Automation
These files are generated by `~/.claude/hooks/synthesize-learnings.sh` which runs on SessionStart. New feedback memory files are automatically synthesized into updates here.

## Archetype filtering (Phase 6.2, 2026-05-20)

Patterns are tagged with `archetypes: [list]` in frontmatter. The UserPromptSubmit hook `~/.claude/hooks/archetype-injector.sh` reads the active project's archetype from `~/.claude/projects.yaml` and emits an additionalContext block listing only the relevant patterns + all `severity: blocking` patterns. Kill switch: `ARCHETYPE_GATE=off`.

## Last synthesis

2026-05-23 EVENING (4 promotes via `/promote` batch — Plan A + Plan B ship-it-system canonical consolidation) — Synthesized 4 feedback files into 3 extends + 1 new pattern; 2 files kept project-local (h2-regen markdown specifics, phase 7.7a.4 retrospective archaeology).

New file (1):
- `cross-repo-ci-discipline.md` — three concrete data points from one session (Plan A: CI to claude-skills, Plan B: intra-repo no CI, rejected Plan-C: cross-repo from old location). Source: `feedback_cross_repo_ci_lives_with_canonical_source.md`.

Extends (3):
- `llm-judge-needs-retry-and-defensive-parse.md` § `--json-schema` field-count breaking point (Haiku 4.5 silently empty `result` field on 6+-field schemas). Source: `feedback_claude_bare_json_schema_field_limit.md`.
- `scoring-design-discipline.md` § aggregation across populations needs a quality floor (tiny abandoned sessions dragged `/system-retro` raw-bucket score from ~3.5 → 2.4). Source: `feedback_session_aggregates_need_duration_floor.md`.
- `cli-integration-discipline.md` § Claude Code transcript slug lossiness (both `/` and `.` encode to `-` — reverse-parse is ambiguous, forward-index instead). Source: `feedback_transcript_slug_encoding_is_lossy.md`.

Pattern count 27 → 28.

---

2026-05-22 NIGHT (1 promote via `/promote` — <your-personal-ai-project> session: Pair B observer wire-up gap) — Extended `verify-before-commit.md` with new section **Greppable wire-up: callback / setInterval / observer**. The existing registry-contract-testing pattern catches modules added to static dispatch dicts; the new section covers the callback/observer/setInterval case where there's no shared key set to assert membership against — only `grep` for the function name in non-test src finds the wire-up gap. Two-incident synthesis: <your-agent-project> 2026-05-17 `dispatch_investigate` (registry case, 14h inert) + <your-personal-ai-project> 2026-05-22 Pair B `runConnectionsObserver` + `runOpinionCrystallizer` (callback case, 24h inert, fixed by PR #199). Source: `feedback_grep_for_function_name_before_claiming_wired`. Pattern count stays 27 (extension, not new file).

---

2026-05-22 EVENING (1 promote via `/promote` batch — Phase 7.7a.2/7.7a.3/7.7a.4 stack ship + retrospective) — Synthesized 2 sourced feedback files into 1 new cross-project pattern; 1 file kept project-local; 5 files were already-promoted in the morning batch (synthesis footers verified). Phase 7.7a.4 brainstorm + spec also completed this session.

New file (1):

1. **`cli-integration-discipline.md`** — Pre-build smoke discipline for CLI wrappers + critical `claude --bare -p` invocation pattern. Two-data-point synthesis: the `--bare` discovery from Phase 7.7a.2 dogfood (saved 22× on cost, 3× on latency mid-cycle) + the generalizable "test the CLI before designing the pipeline" rule from the session retrospective. Covers the envelope+fence parsing pattern for `--output-format json` and includes a pre-build smoke template to paste into specs. Sourced from `feedback_phase_7_7a_2_llm_judge_dogfood_outcome` + `feedback_session_2026_05_22_dogfood_driven_iteration_learnings`.

Kept project-local (1):

- `feedback_phase_7_7a_1_body_jaccard_dogfood_outcome` — phase-specific dogfood outcome (body-Jaccard signal-class limit). The cross-project signal-class lesson is captured in `cli-integration-discipline.md` instead; no need for a separate pattern.

Pattern count: 26 → 27.

---

2026-05-22 (5 promotes via `/promote` batch — Phase 7.7b ship + Phase 7.7a.1 spec) — Synthesized 5 of 10 candidate feedback files; 5 deferred (3 already-resolved, 1 actively-being-addressed in 7.7a.1, 1 session retrospective).

Extensions (no new files):

1. **`hook-design-discipline.md` § PreToolUse hooks can mutate tool_input via `updatedInput`** — verified end-to-end by Phase 7.5 that PreToolUse hooks can amend (not just allow/deny) tool calls via `hookSpecificOutput.updatedInput`. Field name + schema + caveats documented. Source: `feedback_pretooluse_hook_can_mutate_tool_input_via_updatedinput`.

2. **`hook-design-discipline.md` § Concurrency: Stop hooks fire per subagent exit, lock external calls** — Stop hooks fire on every subagent exit (not just session end). Per-invocation caps don't protect against N-way concurrency. flock + mkdir-fallback patterns. Source: `feedback_concurrent_stop_hook_drain_no_lock`. Pairs with `mempalace-discipline.md § palace file lock under concurrent miner load` (second data point).

3. **`llm-judge-needs-retry-and-defensive-parse.md` § Strict-JSON prompt calibration discipline** — retry-and-defensive-parse handles parse failures but doesn't improve first-call success rate. Three calibration moves (replace placeholder syntax with literals; few-shot the schema; try `--output-format json`); inspect ≥5 `.failed/` snapshots before iterating on the prompt. Source: `feedback_haiku_judge_prompt_needs_strict_json_calibration`.

New files (2):

4. **`scoring-design-discipline.md`** — Tier-demotion vs noise-floor bypass: when a tiered scoring system has score-band cutoffs PLUS special per-category rules, make the demotion-vs-bypass semantics explicit. Default to tier-demotion (special rule only affects tier, noise floor still gates inclusion). Self-review checklist + boundary-case trace included. Source: `feedback_tier_demotion_is_not_noise_floor_bypass`.

5. **`data-source-of-truth-discipline.md`** — For systems writing BOTH an append-only event log AND a derived aggregate cache, treat the log as authoritative + the cache as ephemeral. Five rules: log = truth; cache = optimization; document recovery path; pin field semantics at writer site; filter test artifacts during reconstruction. Recovered from Phase 7.4 live-smoke TSV stomp incident. Source: `feedback_jsonl_log_is_source_of_truth_tsv_is_derived_cache`.

Pattern count: 24 → 26.

Deferred (5):
- `session_2026_05_22_phase_7_7b_learnings` (session retrospective; archaeology only).
- `phase_7_2_1_score_zero_always_on_tier_a_pollution` (already resolved by 7.2.2 commit `fb54f5e`).
- `phase_7_2_2_residual_calibration_targets` (already resolved by 7.2.3).
- `description_jaccard_catches_lexical_not_semantic_overlap` (actively being addressed by Phase 7.7a.1 spec, not yet shipped).
- `threadpool_exit_waits_in_flight_by_default` (single data point; wait for 2nd Python-concurrency case before creating a new pattern).

---

2026-05-20 NIGHT (3 promotes via `/promote` + severity re-grading audit) — Promoted 3 feedback memories that had been flagged this morning, plus closed the Phase 6.2 severity gate calibration. Extensions (no new files):

1. **`delegation-discipline.md` § When to compress agent pipelines** — trigger heuristic for /ship v2 compression (config-only single-file changes: cut MoA/designer/researcher/engineer/reviewer dispatch + deploy log; keep patterns.md + smoke + DoD + capture). 3 concrete morning examples (~9-12h saved cumulative). Source: `feedback_ship_compressed_pipeline_for_config_only_changes`.

2. **`hook-design-discipline.md` § Over-block patterns (Long-prompt regex false-positive)** — PreToolUse hooks that scan `tool_input.prompt` false-positive on pipeline boilerplate; 3-tier signal hierarchy (`subagent_type` → anchored `description` → never broad prompt regex). Confirmed cross-project (<your-personal-ai-project> ship-pipeline + crisis-window-ux + /ship Stage 1 memory-keeper). Source: `feedback_hook_long_prompt_regex_false_positive`. Fix in `claude-config 96b03e8`.

3. **`hook-design-discipline.md` § Operating discipline — react to hook errors** — 5-step reaction rule for hook errors visible in tool results: read in full → classify FP/TP in 30s → TaskCreate-with-trigger-text for FPs → course-correct for TPs → pattern-recognize across multiple FPs. Untriaged FPs erode hook safety value. Source: `feedback_react_to_hook_errors_in_tool_results`.

**Severity re-grading audit** (Phase 6.2 follow-up, `claude-config 8cae53a`): 8 archetype-scoped patterns demoted `blocking → warning` so archetype gating does real work. Always-on bucket 18 → 10 (-44%). Demoted: abstract-voice-rules-need-failure-shapes, ai-design-tells, deploy-iteration-discipline, domain-repo-analytics-mapping, nonfiction-sourcing, qa-rules, session-id-persistence-pattern, voice-and-content-rules. Also re-tagged `~/github/<your-project-2>` content-pipeline → brand-content in projects.yaml (`b2c8081`) to close brand-content gap.

Pattern count unchanged (extensions, not new files).

2026-05-20 (3 promotes via `/promote`) — Extended `mempalace-discipline.md` with **3 new sections** in one morning, all dogfood runs of the new `/promote` command (Phase 6.4 shipped earlier today):

1. **`§ Palace file lock under concurrent miner load`** — post-Phase-4+5 steady-state framing: lock contention is now the normal case (~15% during bulk MCP ops), with serialize-where-you-can + 5s-retry-where-you-can't patterns. Source: `feedback_palace_file_lock_under_concurrent_miner_load`.

2. **`§ sync --apply scope-path limitation`** — two predicates must both hold for `--apply` to prune (file missing AND path in known root); `/tmp/`-rooted drawers classify `out_of_scope` and never prune. Workaround = per-drawer MCP `delete_drawer`. Source: `feedback_mempalace_sync_apply_scope_path_limitation`.

3. **`§ Rooms standardization is forward-looking only`** — `mempalace mine` is content-hash-idempotent; re-mining under a new rooms schema does NOT refile existing drawers. No `--force` / `refile` CLI op exists. Source: `feedback_mempalace_rooms_standardization_is_idempotent`.

Bumped `last-validated: 2026-05-20` on mempalace-discipline. Pattern count unchanged at 24 (extensions, not new files).

2026-05-19 NIGHT-6 — Synthesized 10 new feedback files from the MemPalace migration + secrets scrub session (gitleaks, filter-repo, hook bugs, mempalace patterns). Extended 2 existing patterns: `hook-design-discipline` (block-dangerous --force-with-lease regex bug + workaround + cwd-drift Stop hook root cause + self-modification refusal pattern), `secrets-routing` (post-rotation gitleaks audit categorization with 9 bucket classes + `.mcp.json` as a secrets file). Created 2 new patterns: `git-history-scrub-discipline` (5 preconditions + bare --force not --with-lease + replacements file format + filter-repo strips origin + 2nd-round expectation), `mempalace-discipline` (wing-filter fail-open + status check + 3-layer query architecture + bulk-load with gitleaks gate + query discipline). Total patterns: 22 → 24.

2026-05-18 — Synthesized ~100 new feedback files across 7 project memory dirs (workspace, content-system, unstuckwithmolly, <your-agent-project>, nancy, shipitwithmolly, theshipitsystem, marketing-os). Extended 7 existing patterns: `verify-before-commit` (smoke-after-deploy + registry membership from dispatch_investigate incident), `deploy-iteration-discipline` (observability before deploy 2), `n8n-production-patterns` (Telegram-via-n8n + Supabase/PostgREST silent failures), `delegation-discipline` (subagent dispatch realities + hook-bypass phrasing), `never-fabricate` (case-study + vaporware + labeled-demo sub-rules), `documentation-after-build` (cross-surface sweep + markdown-canonical PDF pipeline), `voice-and-content-rules` (nurture voice + audience-matched LPs). Created 5 new patterns: `bot-conversational-ux` (cross-bot UX from 3 Telegram products), `domain-repo-analytics-mapping` (blocking — verify Vercel `domains` before wiring), `hook-design-discipline` (block-vs-remind axis), `gumroad-tiptap-editing` (TipTap commands API recipe), `audit-trail-before-speculative-fix` (instrument-first debugging). Total patterns: 17 → 22.

2026-05-12 (late) — Added `ai-design-tells.md` as the visual/component-level sister to `ai-tell-avoidance.md`. Synthesized from a research session that catalogued AI-coded design defaults (Lovable/v0/Cursor aesthetic — gradient blobs, symmetric grids, indigo primary, gradient pill CTAs) and the Unstuck alternatives. Brief learned pattern + 26-point audit checklist + 1-sentence rule ("if you can't tell which company built this from design alone, rebuild it"). Canonical 474-line reference at `~/github/unstuckwithmolly/docs/ai-design-tells.md`.

2026-05-12 — Phase C of skills-overlap-cleanup: moved `competitive-history.md` and `hook-performance.md` to `memory/` (they're project data, not learned patterns); added `dogfood-by-using-the-system-to-document-itself` (synthesized from doc-site dogfood run); added 4 previously-unlisted patterns (mass-rewrite-mechanics, task-budget-heuristic, qa-rules, research-budgets) to the index.

Previous synthesis 2026-05-07 — synthesized 25 new feedback files since 2026-04-07. Themes: deploy iteration discipline, secrets routing, n8n production patterns. Existing patterns extended: systematic-shortcutting (4 new variants), delegation-discipline (use-existing-skills), voice-and-content-rules (copy-sacred, carousel variety), verify-before-commit (silent failures, clear questions).
