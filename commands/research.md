Launch the **researcher** agent to investigate a topic.

Usage: /research [topic or question]

## Pre-flight (NEW Phase 3)

**Before spawning @tech-researcher or @market-researcher, check MemPalace.** you may have already researched this:

1. `mcp__mempalace__mempalace_search` for the topic
2. Wing filter for project context — fail open per `feedback_mempalace_wing_filter_error_finding_id.md`
3. If past research exists + <30 days old, surface it: "Found prior notes at [path] from [date]. Want a fresh pass or use the existing?"
4. If past research is stale (>30 days), lead with delta-check rather than full re-research
5. Only fan out to external research after confirming MemPalace doesn't cover the question

This saves API credits, time, and avoids researching the same topic in parallel sessions.

## Researcher routing

Route to:
- **@tech-researcher** for APIs / libraries / SDKs / code facts (e.g. "Supabase RLS patterns")
- **@market-researcher** for people / companies / markets / social signals (e.g. "compare Stripe vs Lemon Squeezy")

Both have MemPalace pre-flight built in (Phase 2) — this command-level pre-flight is the FIRST line of defense.

The researcher will:
1. Search docs, APIs, and community resources
2. Evaluate options with trade-offs
3. Output a structured research summary with recommendations
4. Not write any code — research only

Example: /research best practices for Supabase row-level security
Example: /research compare Stripe vs Lemon Squeezy for payments
