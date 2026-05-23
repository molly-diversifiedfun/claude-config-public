# Agent & Skill Orchestration

## Custom Agents (in ~/.claude/agents/)

Your product engineering team:

| Agent | Role | Model | Launch With | When to Use |
|-------|------|-------|-------------|-------------|
| product-lead | PM/Tech Lead | opus | `/plan` | Feature planning, task breakdowns, specs |
| engineer | Senior Engineer | sonnet | `/build` | Implementation, testing, debugging |
| designer | UI/UX Designer | sonnet | direct | UI components, layouts, accessibility |
| reviewer | Code Reviewer | sonnet | `/review` | Pre-merge review (read-only) |
| tech-researcher | API/library research | sonnet | `/research` | Doc exploration, version checks, framework patterns |
| debugger | Debugger | opus | direct | Complex bugs, repros, root cause analysis |
| security | Security Reviewer | opus | direct | Security audits, vulnerability reviews (read-only) |
| project-manager | Project Manager | haiku | direct | TASKS.md, HANDOFF.md, ADRs, summaries (read-only) |
| content-social | Short-form social | sonnet | `/write social` | IG/LI/TT/Reels captions, carousels, hooks. Spawns content-qa. |
| content-longform | Long-form writing | sonnet | `/write longform` | Books, ebooks, blogs, workbooks, brand PDFs |
| content-business | Revenue content | sonnet | `/write business` | Proposals, decks, sales emails (drafts only, never sends) |
| content-qa | Content QA | haiku | direct (auto-spawned) | Read-only checklist QA against learned/qa-rules.md |
| market-researcher | Sales/market research | sonnet | direct | Prospects, competitive intel, fact verification, social signals |

## Slash Commands (in ~/.claude/commands/)

| Command | Purpose |
|---------|---------|
| `/plan [feature]` | Plan a feature → TASKS.md |
| `/build [task]` | Implement a feature or task |
| `/review [files]` | Review changes (read-only) |
| `/research [topic]` | Research before building |
| `/handoff` | Save session state for continuity |

## Installed Skills (in ~/.claude/skills/)

**Thinking:** mental-models, devils-advocate, decision-maker, self-interview, ask-me-the-questions
**Writing:** voice-extractor, humanize-ai-writing
**Career:** resume-rebuilder
**Dev tools:** carl-manager, carl-help, nano-banana, firecrawl
**Content:** brainstorm, code-documenter, handoff

## Agent Prompt Rules

### File reference limit
Agent prompts must reference ≤4 explicit file paths (src/, docs/, supabase/).
The `agent-batch-validator.sh` hook enforces this. Instead of listing paths, tell agents to "grep for X" or "find files matching Y". The same hook also enforces scope-fidelity after the batch-size check: if the last user prompt contained scope tokens (all/every/each + collection noun), the agent prompt MUST restate scope via a `Scope: [...]` line or it will be blocked (kill switch: `SCOPE_GATE=off`).

### Build agents must include tests
Every /build agent prompt MUST include test-writing as a deliverable. Tests ship in the same commit as the feature. Example:
```
"Build X. Also write tests covering: renders, loading/error states, key interactions.
Create test file next to the component. Target 80%+ coverage."
```

### Review order
Launch review agent BEFORE writing final tests. Review catches architectural bugs that tests would just lock in. Order: build → review → fix → test → commit.

## Parallel Execution

ALWAYS use parallel Task/Agent execution for independent operations:

```
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth module
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utilities

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

Split test-writing work by component domain (services, events, pages, etc.), not by coverage percentage. Domain isolation prevents file conflicts between parallel agents.

## Hooks System

Hook types: **PreToolUse** (validation before execution), **PostToolUse** (auto-format, checks after), **Stop** (final verification on session end).

Auto-accept permissions: enable for trusted plans, disable for exploratory work. Never use `dangerously-skip-permissions`. Configure `allowedTools` in `~/.claude.json` instead.

Use **TodoWrite** to track multi-step tasks, verify understanding, enable steering, and show granular steps.
