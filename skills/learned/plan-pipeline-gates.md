---
name: plan-pipeline-gates
description: The /plan pipeline has 3 gated phases — DEFINE, EXPLORE, SPEC — each requiring explicit user approval
severity: warning
archetypes: [always-on]
last-validated: 2026-05-26
---

The /plan pipeline has 3 gated phases:
1. **DEFINE** — brainstorm + brief + user approval
2. **EXPLORE** — engineer research + user approval
3. **SPEC** — write spec

Each gate requires explicit user approval. Do NOT auto-proceed or combine phases.

**Why:** Combining phases produces specs built on unvalidated assumptions. The gates force alignment before investment.

**How to apply:** After completing each phase, present the output and wait for explicit approval before starting the next.
