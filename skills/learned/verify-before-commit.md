---
name: verify-before-commit
description: "Background agent finished" ≠ "work is done." Read agent output, surface silent failures, ask clear questions before staging.
type: learned-pattern
applies-to: [verification, content, build]
projects: [all]
severity: blocking
phase: [build, test, review, deploy]
trigger: [agent-output-staged, silent-success, ambiguous-question]
last-validated: 2026-05-10
---

# Pattern: Verify Agent Output Before Committing

Session 8 committed a May calendar + 14 carousel slides written by background agents without reading a single line. Same pattern as sessions 6-7.

## Rule
"Background agent finished" ≠ "work is done." It means "draft is ready for review."

## Verification checklist for agent-written content:
1. READ the output files (not just check they exist)
2. grep for 47 (AI number tell)
3. grep for banned PM jargon (scope, sprint, standup, decompose, backlog, roadmap)
4. Check Instagram handle is @your-handle
5. Spot-check 2-3 files for voice/tone
6. Verify pillar labels match actual content (don't hack metrics by relabeling)

## Verification for agent-written code:
1. Read the diff
2. Run tests
3. Check for hardcoded secrets
4. Verify it matches the spec's acceptance criteria

## Don't trust silent success on writes

"0 inserted but no errors" is almost always a swallowed Postgres error code, an API auth failure, or a mismatch between the data shape and the table schema. Examples observed:
- HN scraper: `signals.engagement_score` is a generated column → Postgres `428C9` swallowed by try/catch → 0 candidates inserted, no error in Telegram summary.
- Meta IG ingestion: long-lived token expired silently → "success" executions, 0 metrics landing for weeks.
- Weekly Intelligence Report: queries used `source=trend` while workflow writes `source=content_trend` → 0 rows returned, no error.

**Surface the error message in any catch block before assuming silent success.** When verifying agent-written workflow output, check actual row counts in the DB, not just the run summary.

## Verify enum/source values BEFORE writing queries

Before any Supabase query that filters on enum/source/category fields, run:
```sql
SELECT count(*), source, category FROM <table> GROUP BY source, category;
```
to see actual values. Never assume field values match what code documentation or the workflow code suggests. Workflows often drift from the schema names.

## Ask clear yes/no questions, not ambiguous ones

When asking the user a question, never frame it as "Want me to do X, or save for next session?" — "yes" is ambiguous. Always frame as a clear yes/no or A/B with concrete actions. Before sending any question: if the answer is "yes," do I know exactly what to do? If not, reframe.

When asking a multi-part question, label parts unambiguously. "password? + A/B?" → "1" → ambiguous. Use single-question OR consistent numbering throughout, never mixed.

## Enforcement
- CARL GLOBAL_RULE_5 (always on)
- session-retrospective.sh blocks exit without verification
- DoD in `rules/common/definition-of-done.md`

## Cross-refs
- `n8n-production-patterns.md` — generated columns, source/category mismatches, swallowed errors
- `voice-and-content-rules.md` — content QA grep checklist
- Workspace memory: `feedback_clear_questions.md`, `feedback_compute_facts_dont_ask_claude.md`
