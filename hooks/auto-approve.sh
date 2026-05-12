#!/bin/bash
# auto-approve.sh — PermissionRequest hook
# Auto-approves everything except destructive/external operations.
# Safety nets: deny rules in settings.json + block-dangerous.sh hook
# Input: JSON on stdin from Claude Code hook system

deny() {
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$1\"}}"
  exit 0
}

allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","permissionDecision":"allow","permissionDecisionReason":"Auto-approved by auto-approve.sh"}}'
  exit 0
}

# Parse tool name and input from stdin JSON
INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null)

# Extract command for Bash tool checks
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null)

# Block: git push (including force variants, push to remote)
if [ "$TOOL_NAME" = "Bash" ]; then
  if echo "$COMMAND" | grep -qE "git push" 2>/dev/null; then
    deny "git push blocked"
  fi
  # Block: deploy commands
  if echo "$COMMAND" | grep -qE "(vercel|netlify|railway|fly)\s+(deploy|push)" 2>/dev/null; then
    deny "deploy command blocked"
  fi
  # Block: destructive file operations outside project
  if echo "$COMMAND" | grep -qE "rm\s+-rf\s+[~/]" 2>/dev/null; then
    deny "destructive rm blocked"
  fi
  # Block: package publishing
  if echo "$COMMAND" | grep -qE "(npm publish|gem push|pip upload|twine upload)" 2>/dev/null; then
    deny "package publish blocked"
  fi
  # Block: sending messages/emails/notifications to external services
  if echo "$COMMAND" | grep -qE "(curl|wget).*-X\s*(POST|PUT|PATCH|DELETE)" 2>/dev/null; then
    deny "outbound HTTP write blocked"
  fi
fi

# Block: MCP tools that send data to external services (email, calendar, notifications)
case "$TOOL_NAME" in
  mcp__claude_ai_Gmail__gmail_create_draft|mcp__claude_ai_Gmail__gmail_send*)
    deny "Gmail write blocked"
    ;;
  mcp__claude_ai_Google_Calendar__gcal_create_event|mcp__claude_ai_Google_Calendar__gcal_update_event|mcp__claude_ai_Google_Calendar__gcal_delete_event)
    deny "Calendar write blocked"
    ;;
  mcp__claude_ai_Notion__notion-create*|mcp__claude_ai_Notion__notion-update*|mcp__claude_ai_Notion__notion-move*)
    deny "Notion write blocked"
    ;;
  mcp__claude_ai_Canva__commit-editing*|mcp__claude_ai_Canva__comment-on-design)
    deny "Canva write blocked"
    ;;
esac

# Everything else: approve
allow
