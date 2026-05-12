#!/bin/bash
# auto-push-after-commit.sh — PostToolUse hook (matcher: Bash)
# Automatically pushes after every successful git commit.
# Enforces: "push after every commit, never batch"

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // "1"' 2>/dev/null)

# Only act on successful git commits
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

if [ "$EXIT_CODE" != "0" ]; then
  exit 0
fi

# Don't double-push if command already includes push
if echo "$COMMAND" | grep -q 'git push'; then
  exit 0
fi

# Push
echo "📤 Auto-pushing after commit..."
git push 2>&1 || echo "⚠️  Auto-push failed — run 'git push' manually"

exit 0
