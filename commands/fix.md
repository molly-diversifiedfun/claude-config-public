Quick fix mode — no spec, no review pipeline.

Usage: /fix [bug description or error message]

Flow:
1. Assess: is this a bug (→ @debugger) or a small change (→ @engineer)?
2. Fix + regression test
3. Verify the fix resolves the reported symptom (not just "tests pass")
4. Update artifacts if significant: HANDOFF.md, TASKS.md, CLAUDE.md
5. Commit

This is for quick fixes only. If the fix reveals a deeper issue, use /escalate-to build or /escalate-to ship.

Example: /fix login button returns 401 on valid credentials
Example: /fix TypeError: Cannot read property 'map' of undefined in UserList
