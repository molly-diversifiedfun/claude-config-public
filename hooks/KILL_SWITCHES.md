# Hook Kill Switches Reference

Set any of these as environment variables to disable the corresponding hook gate.
Export in your shell or add to `settings.json` → `env` block.

## PreToolUse Gates

| Kill Switch | Hook | What it gates |
|---|---|---|
| `DANGEROUS_GATE=off` | block-dangerous.sh | rm -rf /, force push to main, curl\|sh |
| `PRECOMMIT_GATE=off` | pre-commit-checks.sh | Pre-commit lint, missing tests, remote-ahead |
| `ISSUE_CLOSE_GATE=off` | block-issue-close-without-tests.sh | gh issue close without test evidence |
| `CAPTION_GATE=off` | caption-guard-unified.sh | Freehand SQL caption writes + caption file edits without prompt |
| `MANIFEST_GATE=off` | pre-commit-validate-manifest.sh | Agent manifest validation on commit |
| `WORKFLOW_GATE=off` | workflow-gate.sh | Product-lead without brainstorm, engineer without tests |
| `BATCH_GATE=off` | agent-batch-validator.sh | Agent prompts with >6 file path refs |
| `SCOPE_GATE=off` | agent-batch-validator.sh | Scope-fidelity check on collection nouns |
| `SKILL_INJECT_FOR_AGENT=off` | inject-skills-for-agent.sh | Deprecated alias → agent body injection |

## PostToolUse Gates

| Kill Switch | Hook | What it gates |
|---|---|---|
| `SHIP_PHASE_GATE=off` | ship-phase-gate.sh | 3-deploy rule, observability, smoke check |
| `SHIP_SKILL_TRACK=off` | ship-skill-tracker.sh | Skill invocation logging during /ship |
| `AGENT_EVAL=off` | agent-eval.sh | Both enqueue + drain (full disable) |
| `AGENT_EVAL_DRAIN=off` | agent-eval.sh | Drain only (still enqueues snapshots) |

## UserPromptSubmit Gates

| Kill Switch | Hook | What it gates |
|---|---|---|
| `ARCHETYPE_GATE=off` | archetype-injector.sh | Whole hook (archetype + learned patterns) |
| `MID_SESSION_NUDGE=off` | mid-session-dod-nudge.sh | DoD nudge after 100 tool calls |

## Stop Gates

| Kill Switch | Hook | What it gates |
|---|---|---|
| `RETROSPECTIVE_GATE=off` | session-retrospective.sh | DoD enforcement (grace: 1st miss = nudge, 2+ = block) |
| `MANIFEST_DRIFT_CHECK=off` | stop-check-manifest-drift.sh | Agent manifest drift logging |

## Other Gates

| Kill Switch | Hook | What it gates |
|---|---|---|
| `TEAMMATE_IDLE_GATE=off` | teammate-idle-gate.sh | Block on unfinished teammate work |
| `TASK_COMPLETE_GATE=off` | task-complete-gate.sh | Block on unexecuted literal commands |

## Currently Disabled (in settings.json env)

- `AGENT_EVAL=off` — disabled 2026-05-26 (5 total evals, low signal)
