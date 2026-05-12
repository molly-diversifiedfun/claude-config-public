Mode transition — when current mode isn't enough, escalate without losing work.

Usage: /escalate-to [build|ship]

When to use:
- /fix reveals a deeper issue → /escalate-to build
- /build uncovers a need for full pipeline → /escalate-to ship

Flow:
1. Save current progress (committed work, in-progress state)
2. @product-lead re-assesses scope at the new level
3. Transition to the new mode's workflow
4. @project-manager logs the escalation in TASKS.md

Example: /escalate-to build (when a /fix revealed the auth system needs redesign)
Example: /escalate-to ship (when a /build feature needs security audit + full review)
