Full pipeline mode — memory-aware /ship v2 (vertical-slice v1: Deploy + Smoke).

Usage: /ship [feature description]

## Stage 1 — Pre-flight (memory-keeper) [NEW, GATED]

1. Dispatch @memory-keeper with the feature description.
2. memory-keeper writes `.ship/<date>-<slug>/patterns.md` per its agent definition.
3. Confirm inferred tags with Molly. Edit if wrong.
4. Gate (verified by orchestrator): patterns.md exists, ≥1 pattern listed, project memory referenced.

## Stages 2-8 (existing flow, with patterns.md injected) [INLINE GATES ONLY]

For each Agent dispatch in stages 2–8, prepend the agent's prompt with:
"Apply patterns from .ship/<run>/patterns.md. Read the file before acting.
If a pattern conflicts with the task, raise NEEDS_CONTEXT — don't silently override."

Existing flow:
2. @product-lead writes full spec (user stories, API contracts, data model, error states, privacy/compliance)
3. MoA council consulted on architecture decisions
4. @designer creates design spec (if UI)
5. @tech-researcher / @market-researcher investigate unknowns (if any)
6. @engineer implements with subagent-driven-development; @debugger on-call if BLOCKED
7. Tests ship in same commit as feature (TDD per rules/common/testing.md)
8. @reviewer Tier 2 review (escalate to Tier 3 if high-risk); @security audit (if auth/payments/input handling); @content-qa runs if content tags

## Stage 9 — Deploy + Smoke (engineer + e2e plugin) [NEW, GATED]

1. Engineer pushes to deploy target.
2. Append `## Deploy attempt N` to `.ship/<run>/deploy-log.md` per push (format strict — see spec §7.5).
3. Before deploy 3, engineer MUST declare observability:
   - `## Observability: <how I can see runtime logs>`
   - If logs are opaque, buy observability OR pivot.
4. Real-runtime smoke via `everything-claude-code:e2e-runner`.
5. Append `## Smoke test: <result>` to deploy-log.md.
6. Gate (hook): ship-phase-gate.sh checks 3-deploy-rule, observability, smoke. Hook blocks next Agent dispatch if any check fails.

## Stage 10 — Handoff (project-manager) [INLINE]

@project-manager updates HANDOFF.md, TASKS.md, CLAUDE.md per DoD doc-mapping table.
v1: inline reminder only.

## Stage 11 — Capture (memory-keeper) [NEW]

1. Dispatch @memory-keeper for capture per its agent definition.
2. memory-keeper drafts feedback files into `.ship/<run>/draft-feedback/`.
3. Asks Molly Q1 per draft + Q2 (surprises) + Q3 (synthesis candidate).
4. Approved drafts move to `memory/`, MEMORY.md updated.
5. /commit-push-pr if not already done.

## Final step

@project-manager produces completion summary + cost report.

Auto-proceeds between phases unless an agent flags concerns.

Example: /ship deploy <your-personal-ai-project> phase 12 webhook to railway
Example: /ship add Slack auth to grounded-work landing page
