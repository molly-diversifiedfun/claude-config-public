#!/bin/bash
# agent-batch-validator.sh — PreToolUse hook (matcher: Agent)
# Blocks agent dispatch if the prompt references too many files (>4).
# Enforces CARL GLOBAL_RULE_11.
#
# Input: JSON on stdin { "tool_name": "Agent", "tool_input": { "prompt": "...", "description": "..." } }
# Output: exit 0 = allow, exit 2 = block with feedback message

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

if [ "$TOOL_NAME" != "Agent" ]; then
  exit 0
fi

PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

# Count file patterns in the prompt (src/*.ts, docs/*.md, etc.)
FILE_COUNT=$(echo "$PROMPT" | grep -oE '(src/|docs/|supabase/)[^ ]+\.(ts|tsx|md|sql|js|jsx)' | sort -u | wc -l | tr -d ' ')

# Also count numbered list items that look like file tasks (e.g., "1. `src/foo.ts`")
BACKTICK_FILES=$(echo "$PROMPT" | grep -oE '`[^`]+\.(ts|tsx|md|sql|js|jsx)`' | sort -u | wc -l | tr -d ' ')

# Take the higher count
if [ "$BACKTICK_FILES" -gt "$FILE_COUNT" ]; then
  FILE_COUNT=$BACKTICK_FILES
fi

MAX_FILES=4

if [ "$FILE_COUNT" -gt "$MAX_FILES" ]; then
  echo "⚠️  BATCH SIZE: This agent prompt references $FILE_COUNT files (max $MAX_FILES per CARL GLOBAL_RULE_11)."
  echo ""
  echo "Split into multiple parallel agents with 3-4 files each."
  echo "Files detected:"
  echo "$PROMPT" | grep -oE '(src/|docs/|supabase/)[^ ]+\.(ts|tsx|md|sql|js|jsx)' | sort -u | head -10
  echo ""
  echo "To override: reduce the file list in the prompt, or split into separate agent calls."
  exit 2
fi

exit 0
