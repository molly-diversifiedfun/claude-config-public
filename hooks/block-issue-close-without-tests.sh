#!/bin/bash
# block-issue-close-without-tests.sh — BLOCKS `gh issue close` without test evidence
#
# Receives JSON on stdin from Claude Code PreToolUse hook.
# Only fires on `gh issue close` commands.
# Exit 0 = allow, Exit 2 = block with message.
#
# Kill switch: ISSUE_CLOSE_GATE=off <command>

set -uo pipefail

# Kill switch — fail-open if explicitly disabled
if [[ "${ISSUE_CLOSE_GATE:-on}" == "off" ]]; then
  exit 0
fi

# Shared block logger (no-op if lib missing)
source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null || true

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Exit silently if not gh issue close
if ! echo "$COMMAND" | grep -qE 'gh\s+issue\s+close'; then
  exit 0
fi

# Allow closing as duplicate (--reason)
if echo "$COMMAND" | grep -qiE 'duplicate|dupe'; then
  exit 0
fi

# Check if the close comment mentions tests or E2E
if echo "$COMMAND" | grep -qiE 'test|e2e|verified|coverage|spec'; then
  exit 0
fi

echo "🚫 BLOCKED: Cannot close GitHub issue without mentioning test evidence." >&2
echo "" >&2
echo "DoD requires unit + E2E tests before closing. Include one of:" >&2
echo "  - 'Tests verified' or 'E2E passing'" >&2
echo "  - 'Verified — no code changes needed' (for non-code issues)" >&2
echo "  - 'Closing as duplicate' (for dupes)" >&2
echo "" >&2
echo "If the issue genuinely needs no tests, add '--comment \"Verified — ...\"'" >&2
echo "  Kill switch: ISSUE_CLOSE_GATE=off <command>" >&2
type log_block >/dev/null 2>&1 && log_block "BLOCKED: gh issue close without test evidence" "ISSUE_CLOSE_GATE"
exit 2
