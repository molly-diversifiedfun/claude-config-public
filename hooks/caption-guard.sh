#!/bin/bash
# caption-guard.sh — PreToolUse hook (matcher: Bash)
# Blocks freehand caption INSERT/UPDATE via SQL without using the caption-generator prompt.
# Catches: supabase db query with "SET caption =" that doesn't come from the pipeline script.
#
# Input: JSON on stdin { "tool_name": "Bash", "tool_input": { "command": "..." } }
# Output: exit 0 = allow, exit 2 = block with feedback

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only check Bash calls
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Check if this is a supabase query that sets captions
if echo "$COMMAND" | grep -qi "supabase.*db.*query" && echo "$COMMAND" | grep -qi "SET caption"; then
  # Allow if it's the pipeline script running
  if echo "$COMMAND" | grep -q "produce-month\|stage_captions"; then
    exit 0
  fi

  # Allow if it references the caption-generator prompt
  if echo "$COMMAND" | grep -q "caption-generator"; then
    exit 0
  fi

  # Block freehand caption writes
  echo "BLOCKED: You're writing captions directly via SQL without using the caption-generator prompt."
  echo ""
  echo "RULE: All captions MUST be generated using unstuck/prompts/caption-generator.md"
  echo "Use: python3 scripts/produce-month.py --stage=captions"
  echo "Or read the prompt, fill in inputs, and generate properly."
  echo ""
  echo "If you're fixing a single caption, read caption-generator.md first and follow the process."
  exit 2
fi

exit 0
