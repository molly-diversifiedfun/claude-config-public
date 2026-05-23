Launch the **reviewer** agent to review recent changes.

Usage: /review [optional: specific files or git range]

## Pre-flight (NEW Phase 3)

Before dispatching @reviewer:
1. `mcp__mempalace__mempalace_search` for the area being reviewed (file path, system name, feature topic)
2. Wing filter for active project — fail open per `feedback_mempalace_wing_filter_error_finding_id.md`
3. Pull: prior reviews of the same area, known gotchas, related ADRs, post-incident learnings
4. Pass loaded drawer paths in the reviewer dispatch prompt so reviewer doesn't re-query for the same patterns

The reviewer will:
1. Examine recent changes (git diff or specified files)
2. Check for security, bugs, performance, and architecture issues
3. Output a structured review report
4. **Read-only** — will not modify any files

Example: /review
Example: /review src/auth/
