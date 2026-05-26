# Hooks Reference

~24 shell scripts wired into Claude Code's lifecycle. Each fires automatically on a specific event — they don't depend on Claude "remembering" to invoke them.

Simplified 2026-05-26: agent-eval removed (low signal), CARL domain loading removed (migrated to learned patterns), caption hooks unified, observe-learning stripped to counter-only, session-retrospective redesigned with grace mechanism.

## Lifecycle events

| Event | When |
|---|---|
| `UserPromptSubmit` | Right after the user sends a message, before Claude processes it |
| `PreToolUse` | Before Claude invokes any tool — hook can block or transform |
| `PostToolUse` | After a tool call completes |
| `Stop` | When the session ends |
| `SessionStart` | When a session begins |
| `TeammateIdle` | When a subagent goes idle |
| `TaskCompleted` | When a task is marked complete |
| `PermissionRequest` | When a tool call needs user permission |

## Hook reference

### Context injection (UserPromptSubmit)

| Hook | What | Kill switch |
|---|---|---|
| `carl-loader.sh` | Star-commands only (`*dev`, `*review`, `*brief`). Domain rules removed 2026-05-26. | — |
| `archetype-injector.sh` | Resolves cwd → archetype → injects relevant learned patterns (blocking always-on, others archetype-filtered). ~500 bytes per prompt. | `ARCHETYPE_GATE=off` |
| `mid-session-dod-nudge.sh` | Soft nudge if >100 tool calls + stale HANDOFF.md. Once per day max. | `MID_SESSION_NUDGE=off` |

### Safety gates (PreToolUse)

| Hook | Matcher | What | Kill switch |
|---|---|---|---|
| `block-dangerous.sh` | Bash | Blocks `rm -rf /`, force-push to main, `curl\|sh` | `DANGEROUS_GATE=off` |
| `pre-commit-checks.sh` | Bash | Pre-commit lint + missing-tests + remote-ahead on `git commit` | `PRECOMMIT_GATE=off` |
| `pre-commit-validate-manifest.sh` | Bash | Validates agent manifest on staged manifest/agent commits | `MANIFEST_GATE=off` |
| `block-issue-close-without-tests.sh` | Bash | Blocks `gh issue close` without test evidence | `ISSUE_CLOSE_GATE=off` |
| `caption-guard-unified.sh` | Bash + Write\|Edit | Blocks freehand SQL caption writes AND caption file edits without reading the generator prompt | `CAPTION_GATE=off` |
| `workflow-gate.sh` | Agent | Gates product-lead dispatches without brainstorm, engineer without tests | `WORKFLOW_GATE=off` |
| `agent-batch-validator.sh` | Agent | Enforces ≤6 file refs + scope-fidelity on agent prompts | `BATCH_GATE=off` / `SCOPE_GATE=off` |
| `inject-skills-for-agent.sh` | Agent | Resolves deprecated alias names (engineer→builder, etc.) via full agent body injection. Real manifest agents untouched. | `SKILL_INJECT_FOR_AGENT=off` |

### Observation (PostToolUse)

| Hook | Matcher | What |
|---|---|---|
| `observe-learning.sh` | * | Increments tool counter only. No JSONL logging (stripped 2026-05-26). Feeds mid-session nudge. |
| `content-qa-guarded.sh` | Write\|Edit | PM jargon, AI-tell numbers (47), wrong handle check on content files |
| `prettier-format.sh` | Write\|Edit | Auto-formats JS/TS files |
| `auto-push-after-commit.sh` | Bash | Chains `git push` after every `git commit` |
| `ship-phase-gate.sh` | Agent\|Bash | 3-deploy rule, observability, smoke check. Only active during `/ship` runs. Kill: `SHIP_PHASE_GATE=off` |
| `ship-skill-tracker.sh` | Skill | Logs skill invocations during active `/ship` runs. Advisory only. Kill: `SHIP_SKILL_TRACK=off` |

### Session lifecycle (Stop / SessionStart)

| Hook | Event | What | Kill switch |
|---|---|---|---|
| `session-end-save.sh` | Stop | Backs up HANDOFF.md + TASKS.md. Rate-limited: 1 per project per 10 min. 3-day retention. | — |
| `session-retrospective.sh` | Stop | DoD enforcement with grace: 1st miss = soft nudge, 2nd+ consecutive = hard block. Checks HANDOFF.md + TASKS.md freshness (trimmed from 8 checks to 2 on 2026-05-26). | `RETROSPECTIVE_GATE=off` |
| `stop-check-manifest-drift.sh` | Stop | Logs agent manifest drift. Never blocks. | `MANIFEST_DRIFT_CHECK=off` |
| `mempalace-wrapper.sh` | Stop + SessionStart + Compact | MemPalace session save, auto-mine memory dirs, wake-up injection. 10s timeout. Soft-fails open. | — |
| `session-restore.sh` | SessionStart | Restores session state from previous run | — |
| `synthesize-learnings.sh` | SessionStart | Flags unprocessed feedback files for learned/ synthesis | — |
| `check-model-freshness.sh` | SessionStart | Warns if model refs >90 days stale | — |
| `surface-hook-blocks.sh` | SessionStart | Surfaces recent blocks from past 24h | `SURFACE_HOOK_BLOCKS=off` |
| `pre-compact-save.sh` | Compact | Stashes uncommitted changes before context compaction | — |

### Other events

| Hook | Event | What | Kill switch |
|---|---|---|---|
| `teammate-idle-gate.sh` | TeammateIdle | Blocks if teammate explicitly says work is unfinished | `TEAMMATE_IDLE_GATE=off` |
| `task-complete-gate.sh` | TaskCompleted | Blocks literal "Run X" commands without execution evidence | `TASK_COMPLETE_GATE=off` |
| `auto-approve.sh` | PermissionRequest | Auto-allows reads, blocks git push + deploys + external writes | — |

Full kill switch reference: `hooks/KILL_SWITCHES.md`

All PreToolUse + Stop hooks call `hooks/lib/log-block.sh log_block()` before blocking — appends NDJSON to `~/.claude/logs/hook-blocks.log` for cross-session triage.

## How hooks differ from skills/agents/commands

- **Hooks** run on Claude Code's *runtime events* — they don't go through the model. They're shell scripts that execute, possibly returning a JSON decision (allow / block / transform).
- **Skills/agents/commands** all involve the model — they're prompted invocations of Claude.

Use a hook when:
- The behavior must be *deterministic* (Claude shouldn't decide whether to enforce it)
- It runs on every X event regardless of context
- It needs to block or transform tool inputs/outputs at the boundary
- It's cheap (hooks run on every event — keep them <100ms)

## Hook protocol

Each hook receives a JSON payload over stdin describing the event, and outputs a JSON response over stdout (or empty for "allow"). For PreToolUse blocking:

```bash
#!/usr/bin/env bash
input=$(cat)
if [[ ... ]]; then
  echo '{"decision":"block","reason":"because ..."}' >&2
  exit 2
fi
exit 0
```
