Standard feature mode — lightweight spec, 3-5 agents, auto-proceed.

Usage: /build [feature description or TASKS.md reference]

Flow:
0. **Pre-flight — query MemPalace (NEW Phase 3):**
   - `mcp__mempalace__mempalace_search` for the feature topic + active-project wing
   - Wing-filter fail-open: retry without filter if `Error finding id` (see `feedback_mempalace_wing_filter_error_finding_id.md`)
   - Look for: similar features already shipped, related ADRs, prior implementation gotchas, deferred TODOs that touch this area
   - Surface 3-5 drawers to the user: "I found prior work on this at [paths]. Extending or fresh?"
   - Skip ONLY if /build target is a one-line trivial fix (typo, copy edit) — otherwise always query
1. @product-lead writes lightweight 1-page spec (30 min max): user story + acceptance criteria + test plan
2. @designer creates design spec (if UI — skip if backend-only)
3. @engineer implements with TDD, uses subagent-driven-development for 3+ subtasks
4. @reviewer Tier 1 review (auto-escalates to Tier 2 if concerns)
5. **Walk the spec:** Re-read the spec's Definition of Done / acceptance criteria line by line. For each item, confirm it was actually done — not "probably done," actually verified. If an item says "audit all X" or "document Y," the artifact must exist. Uncompleted items become new tasks or blockers.
6. **Update all artifacts:** Move spec to done/ with completion notes. Update dependent specs, CLAUDE.md, .project-context.md, TASKS.md, HANDOFF.md, and project memory. Verify counts (tests, files, tables) match reality.
7. /commit-push-pr
8. @project-manager tracks throughout, updates TASKS.md

Auto-proceeds between phases unless an agent reports concerns.

If the feature grows beyond /build scope, use /escalate-to ship.

Example: /build implement the login API endpoint from TASKS.md
Example: /build add dark mode toggle to the settings page
Example: /build feature voting UI for GiftShopper roadmap
