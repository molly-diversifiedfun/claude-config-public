#!/bin/bash
# observe-learning.sh — PreToolUse / PostToolUse hook
# Logs tool-use events to activity.jsonl AND increments tool counter (for CARL context brackets).
# Replaces the old separate checkpoint-tracker.sh to reduce subprocess overhead.
# Usage: observe-learning.sh pre|post
# Input: JSON on stdin from Claude Code hook system

PHASE="${1:-unknown}"
CHECKPOINT_DIR="$HOME/.claude/checkpoints"
mkdir -p "$CHECKPOINT_DIR"

# Parse JSON from stdin
INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")
LOG_FILE="$CHECKPOINT_DIR/activity.jsonl"

# Rotate log if >5MB (keep last 20K lines as activity-prev.jsonl)
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(stat -f '%z' "$LOG_FILE" 2>/dev/null || stat -c '%s' "$LOG_FILE" 2>/dev/null || echo "0")
  if [ "$LOG_SIZE" -gt 5242880 ]; then
    tail -20000 "$LOG_FILE" > "$CHECKPOINT_DIR/activity-prev.jsonl" 2>/dev/null
    mv "$CHECKPOINT_DIR/activity-prev.jsonl" "$LOG_FILE" 2>/dev/null
  fi
fi

# For high-frequency read-only tools: log tool name only (no file path) to keep I/O light
# but still enable verification checks in session-retrospective.sh
case "$TOOL_NAME" in
  Read|Glob|Grep)
    echo "{\"ts\":\"$TIMESTAMP\",\"phase\":\"$PHASE\",\"tool\":\"$TOOL_NAME\",\"file\":\"\",\"project\":\"\"}" >> "$LOG_FILE"
    # Still increment counter
    if [ "$PHASE" = "post" ]; then
      COUNTER_FILE="$CHECKPOINT_DIR/.tool_count"
      COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
      echo $((COUNT + 1)) > "$COUNTER_FILE"
    fi
    exit 0
    ;;
esac

# `file` is the per-tool identifier: file_path (Read/Edit/Write), command (Bash),
# skill name (Skill), subagent_type (Agent). Falls back to empty when none match.
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // .tool_input.skill // .tool_input.subagent_type // ""' 2>/dev/null)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // "unknown"' 2>/dev/null)

echo "{\"ts\":\"$TIMESTAMP\",\"phase\":\"$PHASE\",\"tool\":\"$TOOL_NAME\",\"file\":\"$FILE_PATH\",\"project\":\"$PROJECT_DIR\"}" >> "$LOG_FILE"

# Increment tool counter on post phase only
if [ "$PHASE" = "post" ]; then
  COUNTER_FILE="$CHECKPOINT_DIR/.tool_count"
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
  echo $((COUNT + 1)) > "$COUNTER_FILE"
fi

exit 0
