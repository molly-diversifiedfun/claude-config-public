---
name: delegation-discipline
description: Orchestrator gathers context and delegates. Use existing installed skills BEFORE proposing to build.
type: learned-pattern
applies-to: [delegation, process]
projects: [all]
severity: blocking
phase: [pre-flight, brainstorm, define, explore, build]
trigger: [agent-routing, build-vs-reuse, pm-vs-engineer]
last-validated: 2026-05-10
---

# Pattern: Delegation Discipline

The orchestrator gathers context and delegates. It does NOT produce PM artifacts, write build specs, or do the engineer's research.

## Agent routing:
- Product briefs, plans, specs → product-lead
- Solution exploration, architecture → engineer
- UI components, layouts → designer
- Code review → reviewer (before final tests)
- API/library research → researcher
- Complex bugs → debugger

## Common violations:
1. Writing the brief myself when product-lead times out → re-run with better scoping
2. Skipping engineer's exploration → let them research independently
3. Conflating PM work and engineering work → PM says WHAT, engineer says HOW

## Workflow:
1. product-lead writes product brief (problem, landscape, opportunity)
2. engineer researches solutions (how to build, trade-offs)
3. Molly reviews both → go/no-go
4. Then build

## Use existing installed skills BEFORE proposing to build

Molly has 22 plugins with hundreds of skills. The answer is almost always "update the agent definition to use an existing skill," not "build a new thing."

- I once proposed building a multi-phase define→explore→spec→build pipeline when **compound-engineering** already had brainstorm→plan→work installed with approval gates. The fix was updating 2 agent files to reference existing skills, not building a new system.
- The check applies to **external ecosystems too**: ClawHub (13K+ skills), Anthropic Claude skills, MCP servers, n8n nodes. <your-agent-project> kickoff: I proposed 4 custom skills (memory-keeper, Gmail, cadence, drive sweep) before checking ClawHub. After course-correction, found gog/adhd-daily-planner/briefing/gbrain already covered most of it. **Net build was smaller after research, not bigger.**

When a gap is identified:
1. Search installed plugins/skills first (CLAUDE.md skill list, `~/.claude/plugins/` cache)
2. Search the framework's external ecosystem (ClawHub, MCP registry, n8n marketplace)
3. If a plugin has the pattern, update the agent definition to reference it
4. Only build net new if nothing covers the need

## Wire research into production

When strategy/research docs arrive, saving them as a reference doc is step 1. Step 2 is wiring the actionable parts into the production tools that produce content (caption-generator.md, strategy.md, content calendar). A reference doc that doesn't feed into production is just a filing exercise.

When a research doc lands, ask: "which production tools should this change?" — then update those tools directly.

## Enforcement
- CARL WORKFLOW_RULE_5
- Agent definitions in `~/.claude/agents/`
- Agent prompt must reference ≤4 file paths (agent-batch-validator.sh)

## Cross-refs
- `systematic-shortcutting.md` — variant 4 (build vs reuse) and variant 9 (local vs marketplace)
- Workspace memory: `feedback_use_existing_skills.md`, `feedback_playbook_wiring.md`
