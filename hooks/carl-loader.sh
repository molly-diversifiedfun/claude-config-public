#!/bin/bash
# carl-loader.sh — UserPromptSubmit hook (simplified 2026-05-26)
# Domain rules migrated to learned patterns. Only star-commands remain.
# Input: JSON on stdin { "prompt": "...", "cwd": "..." }
# Output: JSON { "additionalContext": "..." } or {}

CARL_GLOBAL="$HOME/.carl"

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# Capture last prompt for downstream hooks
mkdir -p "$HOME/.claude/checkpoints"
echo "$PROMPT" > "$HOME/.claude/checkpoints/last_prompt"

if [ -z "$PROMPT" ]; then echo '{}'; exit 0; fi

# Star-command detection: *dev, *review, *brief, etc.
if [[ "$PROMPT" =~ \*([a-z]+) ]]; then
  SC=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')

  # Find commands file (local project .carl/ overrides global)
  CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
  CMD_FILE=""
  [ -f "$CWD/.carl/commands" ] && CMD_FILE="$CWD/.carl/commands"
  [ -z "$CMD_FILE" ] && [ -f "$CARL_GLOBAL/commands" ] && CMD_FILE="$CARL_GLOBAL/commands"

  if [ -n "$CMD_FILE" ]; then
    RULES=""
    while IFS= read -r line; do
      line="${line%$'\r'}"
      case "$line" in \#*|"") continue ;; esac
      case "$line" in ${SC}_RULE_*|COMMANDS_${SC}_RULE_*) RULES+="- ${line#*=}"$'\n' ;; esac
    done < "$CMD_FILE"

    if [ -n "$RULES" ]; then
      jq -n --arg ctx "[CARL *${SC,,} mode]
$RULES" '{"additionalContext": $ctx}'
      exit 0
    fi
  fi
fi

echo '{}'
exit 0
