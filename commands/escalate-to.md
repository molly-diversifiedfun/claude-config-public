Mode transition — when current mode isn't enough, escalate without losing work.

Usage: /escalate-to [build|ship]

When to use:
- /fix reveals a deeper issue → /escalate-to build
- /build uncovers a need for full pipeline → /escalate-to ship

Flow:
1. Save current progress (committed work, in-progress state)
2. **Pre-flight (NEW Phase 3):** `mcp__mempalace__mempalace_search` for the topic at the NEW scope level — escalation often means past work at the new scope is relevant. Wing-filter fail-open per `feedback_mempalace_wing_filter_error_finding_id.md`.
3. @product-lead re-assesses scope at the new level (with pre-flight context loaded)
4. Transition to the new mode's workflow
5. @project-manager logs the escalation in TASKS.md including which prior patterns informed the rescoping

Example: /escalate-to build (when a /fix revealed the auth system needs redesign)
Example: /escalate-to ship (when a /build feature needs security audit + full review)
