Save current session state for continuity.

Usage: /handoff

## Pre-flight (NEW Phase 3)

Before writing the new HANDOFF entry:
1. `mcp__mempalace__mempalace_search` for the active project + session topic
2. Pull the most recent 3-5 session captures so the new HANDOFF continues the arc, doesn't restart it
3. Identify deferred TODOs from prior sessions — carry them forward into the new HANDOFF if still relevant
4. Wing-filter fail-open per `feedback_mempalace_wing_filter_error_finding_id.md`

This will:
1. Create or update HANDOFF.md with:
   - Current goal and progress
   - What's done and what's remaining
   - Key decisions made this session
   - Carried-forward TODOs from prior sessions
   - Resume instructions for the next session
2. Update TASKS.md with current status
3. Commit all changes with a handoff message
4. Push to remote

Use this before ending a session or when switching contexts.
