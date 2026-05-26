#!/bin/bash
# observe-learning.sh — PostToolUse hook (simplified 2026-05-26)
# Increments tool counter only. JSONL activity logging removed (nothing reads it).
# Counter feeds: mid-session-dod-nudge.sh threshold check.
# Usage: observe-learning.sh post

PHASE="${1:-unknown}"

# Only increment on post phase
if [ "$PHASE" != "post" ]; then
  exit 0
fi

COUNTER_FILE="$HOME/.claude/checkpoints/.tool_count"
mkdir -p "$(dirname "$COUNTER_FILE")"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
echo $((COUNT + 1)) > "$COUNTER_FILE"

exit 0
