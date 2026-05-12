---
name: task-budget-heuristic
description: Before executing a multi-phase task, estimate token cost. If it exceeds ~60% of remaining context, stop and surface phased options before touching anything.
type: learned-pattern
applies-to: [process, memory]
projects: [all]
severity: warning
phase: [brainstorm, build]
last-validated: 2026-05-12
---

# Pattern: Context Budget Check Before Large Tasks

## Rule
Before executing a multi-phase task, estimate token cost. If it exceeds ~60% of remaining context, **stop and surface phased options** before touching anything.

```
estimated_cost ≈ spec_tokens + (N_files × avg_read) + (N_files × avg_write)

if estimated_cost > 60% remaining:
    surface options → phased commits | subagent delegation | scope triage
```

## Trigger conditions (either is enough)
- Task spans >2 file categories (e.g., agent files + config + docs + external APIs)
- Spec or brief is >500 lines / ~10k tokens

## Options to surface
1. **Phased commits** — deliver phases 1-2, commit + push, compact, resume
2. **Subagent delegation** — parallel agents handle independent phases
3. **Scope triage** — must-have vs. deferred

## CLAUDE.md anchor
your 70% context rule is the *reactive* version. This heuristic is the *proactive* version — catch overrun risk before executing, not mid-execution with a half-rewritten codebase.

## Origin
2026-04-07 agent-setup — 5 phases × 1481-line spec would have overflowed before phase 3. Saved to memory as `feedback_scope_check_before_mass_edits.md`.
