Quick fix mode — no spec, no review pipeline.

Usage: /fix [bug description or error message]

Flow:
0. **Pre-flight — query MemPalace (NEW Phase 3):**
   - HIGHEST leverage for /fix: prior bugs in the same area often have captured root causes
   - `mcp__mempalace__mempalace_search` for the symptom (error message excerpt, function name, file path)
   - Filter by active-project wing — fail open per `feedback_mempalace_wing_filter_error_finding_id.md`
   - If a matching prior `feedback_*` drawer exists, lead with "MemPalace suggests this is the [pattern X] class of bug from [prior session date] — verifying it applies before re-investigating"
   - This often shortens /fix from 30 min to 5 min
   - Skip ONLY for typo / formatting / one-line config fixes
1. Assess: is this a bug (→ @debugger) or a small change (→ @engineer)?
2. Fix + regression test
3. Verify the fix resolves the reported symptom (not just "tests pass")
4. Update artifacts if significant: HANDOFF.md, TASKS.md, CLAUDE.md
5. Commit

This is for quick fixes only. If the fix reveals a deeper issue, use /escalate-to build or /escalate-to ship.

Example: /fix login button returns 401 on valid credentials
Example: /fix TypeError: Cannot read property 'map' of undefined in UserList
