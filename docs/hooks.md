# Hooks Reference

32 shell scripts wired into Claude Code's lifecycle. Each fires automatically on a specific event — they don't depend on Claude "remembering" to invoke them. v1.1 adds 11 hooks (Phase 7.5 / 7.6 / 7.7c / 8.0 / 8.1) — see `CHANGELOG.md`.

## Lifecycle events

| Event | When |
|---|---|
| `UserPromptSubmit` | Right after the user sends a message, before Claude processes it |
| `PreToolUse` | Before Claude invokes any tool — hook can block or transform |
| `PostToolUse` | After a tool call completes |
| `Stop` | When the session ends |
| `PreCompact` | Before context compaction |

Hooks are configured in `~/.claude/settings.json` under each event's `hooks` array, with optional `matcher` regex to scope them to specific tool names.

## Hook reference

### Context loading

| Hook | Event | What |
|---|---|---|
| `carl-loader.sh` | UserPromptSubmit | Reads the user's prompt, decides which CARL rule files apply, injects them into context |
| `check-model-freshness.sh` | SessionStart | Warns if model references in CLAUDE.md are >90 days stale |
| `synthesize-learnings.sh` | SessionStart | Flags unprocessed feedback files for synthesis into `learned/` patterns |

### Validation / blocking

| Hook | Event | What |
|---|---|---|
| `agent-batch-validator.sh` | PreToolUse:Agent | Enforces ≤4 file path refs in agent prompts (forces "grep for X" patterns instead of explicit lists) |
| `block-dangerous.sh` | PreToolUse:Bash | Blocks dangerous commands (`rm -rf /`, force pushes to main, etc.) |
| `block-issue-close-without-tests.sh` | PreToolUse | Prevents closing GitHub issues without proof of test runs |
| `caption-guard.sh` | PostToolUse:Write\|Edit | Enforces caption rules (handle correctness, banned phrases, AI-tell numbers) on caption files |
| `caption-pipeline-guard.sh` | PreToolUse | Ensures captions go through the prompt template, not freehand inline writing |
| `content-qa-guarded.sh` | PostToolUse:Write\|Edit | Runs content QA (PM jargon, banned numbers like 47, wrong handles) on content files |
| `pre-commit-checks.sh` | PreToolUse:Bash | Pre-commit hook injection for `git commit` — runs lint/typecheck/format |
| `validate-n8n-workflow.sh` | PreToolUse | Validates n8n workflow JSON before write |
| `workflow-gate.sh` | PreToolUse | Gates workflow transitions (plan → build → ship) on prerequisites |
| `ship-phase-gate.sh` | PostToolUse:Agent\|Bash | Gates `/ship` Stage 9 (Deploy + Smoke). Activates only when `.ship/<run>/patterns.md` is present (ancestor walk, ≤4 levels). Enforces 3-deploy rule (block), observability declaration (warn), smoke-test section (warn). See `docs/ship-pipeline-v2.md`. |

### Auto-actions

| Hook | Event | What |
|---|---|---|
| `auto-approve.sh` | PreToolUse | Auto-approves specific low-risk tool calls |
| `auto-push-after-commit.sh` | PostToolUse:Bash | Chains `git push` after every `git commit` per the always-push rule |
| `prettier-format.sh` | PostToolUse:Write\|Edit | Auto-formats JS/TS files via prettier |

### Session management

| Hook | Event | What |
|---|---|---|
| `session-retrospective.sh` | Stop | 7-check Definition-of-Done enforcement; blocks session end if incomplete |
| `session-end-save.sh` | Stop | Saves session state for continuity |
| `session-restore.sh` | SessionStart | Restores session state from previous run |
| `pre-compact-save.sh` | PreCompact | Saves state before context compaction (so nothing's lost) |
| `observe-learning.sh` | PostToolUse | Logs all activity, increments learning counter, rotates log at 5MB |

### UI / status

| Hook | Event | What |
|---|---|---|
| `gsd-statusline.js` | StatusLine | Custom status line (Get Shit Done) showing current task / time / project |

## How hooks differ from skills/agents/commands

- **Hooks** run on Claude Code's *runtime events* — they don't go through the model. They're shell scripts that execute, possibly returning a JSON decision (allow / block / transform).
- **Skills/agents/commands** all involve the model — they're prompted invocations of Claude.

Use a hook when:
- The behavior must be *deterministic* (Claude shouldn't decide whether to enforce it)
- It runs on every X event regardless of context
- It needs to block or transform tool inputs/outputs at the boundary
- It's cheap (hooks run on every event — keep them <100ms)

## Configuring hooks

In `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/carl-loader.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/block-dangerous.sh" }
        ]
      }
    ]
  }
}
```

The `matcher` pattern is matched against tool names (regex; `*` for any). Multiple hooks can be wired to the same event; they run in order.

## Hook protocol

Each hook receives a JSON payload over stdin describing the event, and outputs a JSON response over stdout (or empty for "allow"). For PreToolUse blocking:

```bash
#!/usr/bin/env bash
input=$(cat)
# Inspect $input (tool name, params, etc.)
if [[ ... ]]; then
  echo '{"decision":"block","reason":"because ..."}'
  exit 0
fi
# Otherwise allow (no output, exit 0)
```

For PostToolUse and other observational hooks: just log/process; the response is ignored.

## Performance

Hooks fire on every relevant event. Keep them fast (<100ms ideal). The most common hook timing failure is `carl-loader.sh` doing too much disk I/O on every prompt — see `learned/hook-performance.md` for patterns.

## Adding a new hook

```sh
# Write the hook
cat > ~/.claude/hooks/my-hook.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# ... your logic
EOF
chmod +x ~/.claude/hooks/my-hook.sh

# Wire it in ~/.claude/settings.json under the right event

# Sync to repo
cd ~/github/claude-config
./bin/sync.sh
git add -A && git commit -m "feat(hooks): add my-hook" && git push
```
