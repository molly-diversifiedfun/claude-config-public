#!/usr/bin/env bash
# caption-pipeline-guard.sh — PreToolUse hook
#
# Blocks Write/Edit to <your-first-brand-slug>/captions/** unless the caller has read
# <your-first-brand-slug>/prompts/caption-generator.md in the same session.
#
# Enforces Spec 9a flag 3: "no freehand captions, must go through prompt".
#
# Wire in settings.json under hooks.PreToolUse.matcher="Write|Edit":
#   { "type": "command", "command": "$HOME/.claude/hooks/caption-pipeline-guard.sh" }
#
# Kill switch: CAPTION_PIPE_GATE=off <command>

set -euo pipefail

# Kill switch — fail-open if explicitly disabled
if [[ "${CAPTION_PIPE_GATE:-on}" == "off" ]]; then
  exit 0
fi

# Shared block logger (no-op if lib missing)
source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null || true

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
  */<your-first-brand-slug>/captions/*) ;;
  *) exit 0 ;;
esac

# Check session log for read of caption-generator.md
SESSION_LOG="${CLAUDE_SESSION_LOG:-/tmp/claude-session-tools.log}"
PROMPT_PATH="<your-first-brand-slug>/prompts/caption-generator.md"

if [ -f "$SESSION_LOG" ] && grep -q "$PROMPT_PATH" "$SESSION_LOG"; then
  exit 0
fi

# Block
cat <<EOF >&2
{
  "decision": "block",
  "reason": "Caption pipeline violation: writing to $FILE without first reading $PROMPT_PATH. Captions must be generated via the prompt template (Spec 9a flag 3, <your-content-pipeline> rules). Read $PROMPT_PATH, fill the 5 inputs, then retry."
}
EOF
type log_block >/dev/null 2>&1 && log_block "BLOCKED: caption pipeline violation — write to $FILE without reading $PROMPT_PATH" "CAPTION_PIPE_GATE"
exit 2
