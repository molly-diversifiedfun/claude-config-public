---
name: systematic-shortcutting
description: Don't skip steps to produce output faster. The root cause of most session corrections.
type: learned-pattern
applies-to: [process, delegation, scope, memory]
projects: [all]
severity: blocking
phase: [pre-flight, brainstorm, define, explore, build, review, deploy, capture]
trigger: [skip-step, summarize-from-secondary, narrow-scope, build-vs-reuse]
last-validated: 2026-05-10
---

# Pattern: Systematic Shortcutting

The root cause of most session corrections. I skip steps to produce output faster.

## The 13 variants (all observed, all corrected by Molly):
1. Used assumptions instead of reading actual source material
2. Wrote PM deliverables myself instead of delegating to product-lead
3. Skipped engineer's solution exploration phase
4. Proposed building new instead of checking installed skills first
5. Skipped brainstorm to write brief faster
6. Narrowed scope to move faster when Molly said "all brands"
7. Produced output without required user dialogue
8. Skipped workflow steps I wrote 20 minutes earlier
9. Only checked local installs, didn't search external marketplace
10. **Narrowed chief-of-staff scope to a single first workflow** (<your-agent-project> kickoff: "which first workflow?" instead of building the broad palette day 1). When framing is "employee" / "chief of staff" / "talk to it like a person," default to FULL scope. Architectural manage-up gates handle safety — don't conflate "safe scope" with "narrow scope."
11. **Jumped to engineering before running the product cycle.** New project kickoff order: brief (problem-only) → engineer exploration → parallel reviewers (designer/security/architect) → reviewer consolidator → decisions locked → THEN scaffold. Don't be fooled by "we already have a stack analysis" — pasted context is input, not the brief.
12. **Proposed dispatch shape ("5 parallel subagents") without reading the actual plan.** Subagent-driven-development only fits pure code. Phase 1 tends to be account-bound infra (Supabase project create, GCP OAuth, Railway deploy) that needs Playwright + human loop, not subagents. Read the plan's task descriptions BEFORE proposing dispatch — classify each as (a) pure code, (b) account-bound, (c) hybrid (split).
13. **Didn't read project memory at session start.** Project-scoped `project_*.md` and `reference_*.md` capture gotchas (Supabase MCP scope, Railway TTY blockers, Playwright auth fallback, GCP quota) that prevent re-deriving the same workarounds. Read them BEFORE the first tool call on the project's code.

## Recurring failure shape

I summarize from secondary sources (HANDOFF, memory, my own earlier proposals) instead of reading the primary source. Same root every time: skip a step (read the plan / read the brief / write the brief / check installed skills) to produce output faster (propose a dispatch shape / write code / pick a stack).

## The fix — before every action:
- Did I read actual source material? (the plan, the brief, the project memory — not assumptions or summaries)
- Did I check what already exists? (local + external + project memory)
- Am I following the defined workflow IN ORDER? (brief before exploration, exploration before review, review before code)
- Did I have dialogue with the user if required?
- Am I delegating to the right agent?
- Am I accepting the full stated scope? (employee = broad palette, not single workflow)

If ANY answer is no, do that step first.

## Heuristic — "where's the brief?"

If a fresh Claude session asked "where's the brief?" and the answer is "we discussed it in conversation," the brief doesn't exist yet. Write it before any other artifact.

## Enforcement
- CARL WORKFLOW_RULE_0 encodes this checklist
- session-retrospective.sh blocks exit without learnings
- agent-batch-validator.sh prevents oversized agent prompts

## Cross-refs
- `delegation-discipline.md` — which agent does what
- `deploy-iteration-discipline.md` — pushing-feels-like-progress as a shortcut
- Workspace memory: `feedback_dont_narrow_employee_scope.md`, `feedback_run_product_cycle_first.md`, `feedback_read_plan_before_proposing_dispatch_shape.md`, `feedback_session_nancy_4_7_4_8_learnings.md`
