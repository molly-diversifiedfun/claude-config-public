---
name: audit-trail-before-speculative-fix
description: For silent-failure classes, BUILD the audit trail (stamp evidence on every demote/skip/refuse) BEFORE shipping a speculative fix. For LLM agent bugs, query the transcript table FIRST.
type: learned-pattern
applies-to: [build, verification, observability]
projects: [all]
severity: warning
phase: [debug, build]
trigger: [silent-failure-debug, llm-agent-bug, pipeline-leak]
last-validated: 2026-05-18
archetypes: [always-on]
---

# Pattern: Audit Trail Before Speculative Fix

When an audit hypothesizes a root cause for a silent-failure class, the first move is NOT to ship the fix. It's to instrument so the next occurrence produces evidence.

## The two-step discipline

1. **Build the audit-trail PR first.** Every executor that demotes / fails / defers / skips a candidate MUST stamp `evidence.<reason_key>` + write an `agent_events` row (or equivalent). Blind demotions are an architectural defect that hides 100% pipeline leaks.
2. **Wait for fresh evidence.** Let the instrumented system run once. Read the audit trail. THEN ship the fix.

<your-agent-project> (2026-05-17): an audit hypothesized "L1 over-queueing" as the root cause of a noise issue. Real root cause was a markdown-JSON parser failure that demoted everything silently. Speculative fix would have masked the real bug. The instrumented version surfaced the parser error within one run. (<your-agent-project>/feedback_session_2026-05-17_unfuck_full_arc.md, feedback_executor_audit_trail_floor.md)

## For LLM agent bugs: query the transcript FIRST

When a user reports an agent bug ("I can't write emails", "sent!" but nothing sent, agent fabricates), the first move is NOT to inspect code. It's to query the conversations + tool_call_log tables.

The signal you're looking for:
- Was the tool even called? (If no, persona/routing bug)
- Is the tool in the toolset for that user? (If no, wiring bug)
- Did the tool succeed but return empty? (If yes, data/auth bug)
- Did the tool succeed but model ignored result? (If yes, prompt bug)

Each branch has a different fix. Without the transcript you're guessing. <your-personal-ai-project>: 3 real bugs found in 30 turns by reading the chat log table — none visible in code. (nancy/feedback_chat_log_review_finds_real_bugs.md, workspace/feedback_read_actual_conversations_to_debug.md)

## Persona fixes are symptom-fixing

When the LLM says "I can't do X" but the tool IS wired, the bug is usually one of:
1. Persona system prompt has counter-prior ("be conservative, refuse if uncertain")
2. Tool description is vague enough that the model doesn't recognize when to call
3. Tool is in the toolset but blocked by canUseTool / permission gate

Fixing the persona prose is the LAST move. Check 1-3 first. (nancy/feedback_treat_root_cause_not_symptom.md, workspace/feedback_capability_awareness_in_persona.md)

## Identity injection for multi-user systems

Multi-user tool wiring is necessary but not sufficient. The LLM defaults to the persona's primary subject if not told otherwise. Inject a per-turn identity block:

```
## Current chat
This is {{user_name}}, NOT {{persona_primary_subject}}. Their goals: {{user_goals}}. Treat their messages as theirs, not as test messages about {{persona_primary_subject}}.
```

Caught in <your-personal-ai-project> when the bot started answering Sean as if Sean were the user. (workspace/feedback_identity_injection_for_multi_user.md)

## Cross-refs
- `verify-before-commit.md` — registry membership, smoke after deploy
- `deploy-iteration-discipline.md` — before deploy 2, verify diagnostics
- `delegation-discipline.md` — when to call debugger vs engineer
- Project memory: <your-agent-project> `feedback_executor_audit_trail_floor.md`, nancy `feedback_treat_root_cause_not_symptom.md`
