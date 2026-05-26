---
name: documentation-after-build
description: Docs ship in the same commit as the feature. DoD enforces this. Three failures on the security-hardening build (2026-03-26) when docs were deferred to follow-up commits that never landed.
type: learned-pattern
applies-to: [process, verification, build]
projects: [all]
severity: warning
phase: [verify, capture]
last-validated: 2026-05-12
archetypes: [always-on]
---

# Pattern: Documentation After Build

Three failures on the security-hardening build (2026-03-26):
1. Skipped all docs until you asked "was updating documentation part of your mandate?"
2. Even then, missed the 74-table RLS audit from acceptance criteria
3. you had to ask to save session state — "you need to be doing this on your own"

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

## Cross-surface sweep when product attributes change

When a product attribute changes (price, module count, name, included/excluded features), grep ALL doc surfaces before considering the change done. Old planning docs become liability the moment the product evolves.

Surfaces to sweep:
- welcome.md, gumroad-deliverables.md, gumroad-product-spec.md
- Landing pages (HTML/TSX), JSON-LD blocks, llms.txt
- Email templates (Resend), Notion product templates
- README.md, CLAUDE.md, brand PDFs, sales decks
- The marketing site for that brand (separate repo)

Single canonical source pattern: keep `product-ladder.yml` (or equivalent) as the one place truth lives, then grep the canonical key from there to verify each surface matches. Stale "Module 0/1/2" counts in welcome.md after restructuring caused 3 different "what's included" answers in the same product week (unstuckwithmolly 2026-05-13/14).

## Markdown-canonical pipeline for branded PDFs

When a PDF + a webpage describe the same product, the markdown content file is the canonical source. Edit `.md` → regenerate `.pdf` via the build script. Never edit the PDF directly (ReportLab regeneration will overwrite). The webpage reads the SAME `.md` via fetch. One edit, two surfaces in sync.

## Enforcement
- rules/common/definition-of-done.md (full checklist with doc mapping)
- CARL WORKFLOW_RULE_6 (run DoD before committing)
- session-retrospective.sh (blocks exit without handoff)
