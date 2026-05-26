---
name: plan-artifact-discipline
description: Save /plan artifacts to docs/briefs/ and docs/designs/ — never keep planning only in conversation context
severity: warning
archetypes: [always-on]
last-validated: 2026-05-26
---

Every /plan must save artifacts to `docs/briefs/<feature>-brief.md` and `docs/designs/<feature>-exploration.md`. Planning work that lives only in conversation context is lost at session end.

**Why:** Plans discussed in conversation but never written to disk get compacted away or lost across sessions. The brief and exploration docs are the durable artifacts.

**How to apply:** After any /plan phase completes, check that the output landed in the right directory before proceeding to the next phase.
