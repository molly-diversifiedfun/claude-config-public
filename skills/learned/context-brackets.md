---
name: context-brackets
description: Adapt behavior based on context window usage — FRESH (lean), MODERATE (reinforce), DEPLETED (checkpoint + handoff)
severity: warning
archetypes: [always-on]
last-validated: 2026-05-26
---

Adapt behavior based on how much context window remains:

**FRESH (60-100% remaining):**
- Lean mode — minimal overhead
- Batch operations aggressively
- Work in current context unless task exceeds 500 LOC
- Spawn agents only for explicitly parallel work

**MODERATE (40-60% remaining):**
- Re-state current task goal after 5+ exchanges
- Re-read requirements before architectural decisions
- Consider spawning agents for tasks expecting >300 LOC
- Summarize approach before implementation

**DEPLETED (25-40% remaining):**
- Checkpoint progress before any multi-step operation
- Summarize what's being built before any code generation
- Surface context warning before accepting complex tasks
- Prepare handoff summary proactively
- Recommend fresh session for heavy remaining work

**Why:** Context window depletion causes lost context, repeated work, and degraded output quality. Proactive adaptation prevents the cliff.

**How to apply:** Monitor context usage. At ~70% (per CLAUDE.md), execute the context management checklist. Below 40%, shift to checkpoint-and-handoff mode.
