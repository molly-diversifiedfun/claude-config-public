#!/bin/bash
# block-issue-close-without-tests.sh — BLOCKS `gh issue close` without test evidence
#
# Receives JSON on stdin from Claude Code PreToolUse hook.
# Only fires on `gh issue close` commands.
# Exit 0 = allow, Exit 2 = block with message.

set -uo pipefail

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

echo "🚫 BLOCKED: Cannot close GitHub issue without mentioning test evidence."
echo ""
echo "DoD requires unit + E2E tests before closing. Include one of:"
echo "  - 'Tests verified' or 'E2E passing'"
echo "  - 'Verified — no code changes needed' (for non-code issues)"
echo "  - 'Closing as duplicate' (for dupes)"
echo ""
echo "If the issue genuinely needs no tests, add '--comment \"Verified — ...\"'"
exit 2
