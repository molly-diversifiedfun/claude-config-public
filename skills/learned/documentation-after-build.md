---
name: documentation-after-build
description: Docs ship in the same commit as the feature. DoD enforces this. Three failures on the security-hardening build (2026-03-26) when docs were deferred to follow-up commits that never landed.
type: learned-pattern
applies-to: [process, verification, build]
projects: [all]
severity: blocking
phase: [verify, capture]
last-validated: 2026-05-12
---

# Pattern: Documentation After Build

Three failures on the security-hardening build (2026-03-26):
1. Skipped all docs until Molly asked "was updating documentation part of your mandate?"
2. Even then, missed the 74-table RLS audit from acceptance criteria
3. Molly had to ask to save session state — "you need to be doing this on your own"

## After every /build, /fix, or /ship — do ALL of this automatically:

1. Walk the spec's Definition of Done line by line
2. Update ALL stale artifacts:
   - TASKS.md (mark complete, add discovered work)
   - HANDOFF.md (current state for next session)
   - CLAUDE.md (if new tables, functions, patterns)
   - ADRs (if architectural decisions made)
   - Manual test checklist (untestable items)
3. Run /update-memory at end of session

## Key principle
"Ready to commit" means docs are updated. Not "code works, docs later."

## Enforcement
- rules/common/definition-of-done.md (full checklist with doc mapping)
- CARL WORKFLOW_RULE_6 (run DoD before committing)
- session-retrospective.sh (blocks exit without handoff)
