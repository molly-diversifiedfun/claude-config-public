Launch the full define → explore → spec pipeline.

Usage: /plan [feature or problem description]

## STEP 0: Pre-flight — query MemPalace for prior context (NEW Phase 3)

Before the mandatory checklist below, the orchestrator queries MemPalace at the command level so context flows DOWN into product-lead, engineer, and any agent spawned:

1. `mcp__mempalace__mempalace_search` for the topic + active-project wing if detectable from cwd
2. **Wing-filter fail-open:** if `Error finding id`, retry without the wing filter (see `feedback_mempalace_wing_filter_error_finding_id.md`)
3. Surface the 3-5 most-relevant drawers to the user BEFORE Phase 1a: "I found prior briefs / decisions on this topic at [paths]. Should I extend or start fresh?"
4. If the user says extend: lead Phase 1a with the prior context loaded; product-lead's `ask-questions-if-underspecified` will be more focused
5. If the user says fresh: log that decision so memory-keeper Stage 11 captures the divergence
6. Skip Step 0 for trivial /plan calls (rare; /plan usually warrants the query)

## STEP 1: MANDATORY CHECKLIST (do this AFTER pre-flight)

Create a TodoWrite checklist with these items. Do NOT skip any step. Check each off as you complete it.

```
- [ ] Step 0: Pre-flight MemPalace query (above) — done
- [ ] Phase 1a: Ask clarifying questions (invoke ask-questions-if-underspecified)
- [ ] Phase 1b: Brainstorm with user (invoke compound-engineering:workflows:brainstorm OR brainstorm skill — have a DIALOGUE, don't just produce output)
- [ ] Phase 1c: Write product brief (problem, landscape, hypothesis, metrics, risks)
- [ ] Phase 1d: Stress-test brief (invoke devils-advocate)
- [ ] Phase 1e: GATE — present brief to user, get explicit approval
- [ ] Phase 2a: Engineer reads approved brief
- [ ] Phase 2b: Engineer researches solutions independently
- [ ] Phase 2c: Engineer proposes 2-3 approaches with trade-offs
- [ ] Phase 2d: GATE — present exploration to user, get explicit approval
- [ ] Phase 3a: Product-lead writes spec informed by brief + exploration
- [ ] Phase 3b: Update TASKS.md
```

## Flow

### Phase 1: DEFINE (product-lead + user dialogue)

The product-lead MUST have a conversation with the user before writing anything.

1. **ASK QUESTIONS FIRST.** Invoke `ask-questions-if-underspecified`. Do not skip this. The user has context that research files don't capture.
2. **BRAINSTORM WITH THE USER.** Invoke `compound-engineering:workflows:brainstorm` or the `brainstorm` skill. This is a DIALOGUE — explore the problem space together. Ask what they've tried, what they want, what constraints exist. The conversation IS the product work.
3. ONLY AFTER the dialogue: write the product brief (problem, landscape, hypothesis, metrics, risks). Save to `docs/briefs/<feature>-brief.md`
4. Invoke `devils-advocate` to stress-test the brief.
5. **GATE: Present the brief to the user. Get explicit "approved" before proceeding.**

### Phase 2: EXPLORE (engineer)

The engineer independently researches HOW to build it. Only starts after the brief is approved.

6. **CHECK: Does `docs/briefs/<feature>-brief.md` exist?** If not, go back to Phase 1.
7. @engineer reads the approved brief
8. @engineer invokes research skills for external patterns + codebase patterns
9. @engineer proposes 2-3 approaches with trade-offs
10. Exploration saved to `docs/explorations/<feature>-exploration.md`
11. **GATE: Present the exploration to the user. Get explicit approval.**

### Phase 3: SPEC (product-lead)

Now — with an approved brief AND an approved approach — the product-lead writes the spec.

12. **CHECK: Do both `docs/briefs/` and `docs/explorations/` artifacts exist?** If not, go back.
13. @product-lead writes the spec informed by both
14. Spec saved to `.specs/tasks/todo/<feature>.feature.md`
15. @project-manager updates TASKS.md

Then hand off to /build or /ship for implementation.

## When to Skip Phases

- **Small, well-understood features**: Skip to `/build` instead. No brief needed.
- **Problem defined, solution unclear**: Skip Phase 1, do Phase 2 + 3.
- **New system or product**: Do ALL 3 phases. This is the default. Do not skip.

## Examples

```
/plan creative team agent system          → all 3 phases (new system)
/plan add email sequences to Unstuck      → Phase 1 + 2 + 3 (new capability)
/plan fix the intake form validation      → skip to /build (small fix, no brief needed)
```
