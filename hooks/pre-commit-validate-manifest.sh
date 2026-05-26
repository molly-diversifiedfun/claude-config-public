#!/usr/bin/env bash
# PreToolUse:Bash hook that detects `git commit` invocations touching
# manifest or agents/, runs validate-manifest.sh, blocks on failure.
# Kill switch: MANIFEST_GATE=off
set +e

if [ "$MANIFEST_GATE" = "off" ]; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input', {}).get('command', ''))" 2>/dev/null)

if ! echo "$COMMAND" | grep -qE "git commit"; then
  exit 0
fi

STAGED=$(git diff --cached --name-only 2>/dev/null)
if ! echo "$STAGED" | grep -qE "(agent-skill-manifest\.yaml|^\.claude/agents/|^agents/)"; then
  exit 0
fi

VALIDATE_OUTPUT=$(bash "$HOME/.claude/scripts/validate-manifest.sh" 2>&1)
RC=$?

if [ "$RC" -ne 0 ]; then
  source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null
  if command -v log_block >/dev/null; then
    log_block "pre-commit-validate-manifest" "manifest validation failed" "$COMMAND"
  fi
  echo "🚫 manifest validation failed:" >&2
  echo "$VALIDATE_OUTPUT" >&2
  echo "" >&2
  echo "Kill switch: export MANIFEST_GATE=off" >&2
  exit 2
fi

exit 0
