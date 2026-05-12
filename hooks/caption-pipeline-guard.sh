#!/usr/bin/env bash
# caption-pipeline-guard.sh — PreToolUse hook
#
# Blocks Write/Edit to unstuck/captions/** unless the caller has read
# unstuck/prompts/caption-generator.md in the same session.
#
# Enforces Spec 9a flag 3: "no freehand captions, must go through prompt".
#
# Wire in settings.json under hooks.PreToolUse.matcher="Write|Edit":
#   { "type": "command", "command": "$HOME/.claude/hooks/caption-pipeline-guard.sh" }

set -euo pipefail

# Read tool input from stdin (Claude Code passes JSON)
INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check Write/Edit
case "$TOOL" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

# Only guard caption paths
case "$FILE" in
  */unstuck/captions/*) ;;
  *) exit 0 ;;
esac

# Check session log for read of caption-generator.md
SESSION_LOG="${CLAUDE_SESSION_LOG:-/tmp/claude-session-tools.log}"
PROMPT_PATH="unstuck/prompts/caption-generator.md"

if [ -f "$SESSION_LOG" ] && grep -q "$PROMPT_PATH" "$SESSION_LOG"; then
  exit 0
fi

# Block
cat <<EOF >&2
{
  "decision": "block",
  "reason": "Caption pipeline violation: writing to $FILE without first reading $PROMPT_PATH. Captions must be generated via the prompt template (Spec 9a flag 3, content-system rules). Read $PROMPT_PATH, fill the 5 inputs, then retry."
}
EOF
exit 2
