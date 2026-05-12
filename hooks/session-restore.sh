#!/bin/bash
# session-restore.sh — SessionStart hook
# Restores context from HANDOFF.md, TASKS.md, and recent memories.

# Parse project dir from stdin JSON, fall back to cwd
INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
MEMORIES_DIR="$HOME/.claude/memories"

if [ -f "$PROJECT_DIR/HANDOFF.md" ]; then
  echo "📋 HANDOFF.md found — loading session context:"
  echo "---"
  cat "$PROJECT_DIR/HANDOFF.md"
  echo "---"
fi

if [ -f "$PROJECT_DIR/TASKS.md" ]; then
  echo "✅ TASKS.md found — loading task state:"
  echo "---"
  cat "$PROJECT_DIR/TASKS.md"
  echo "---"
fi

# Load recent memories (last 7 days)
if [ -d "$MEMORIES_DIR" ]; then
  RECENT=$(find "$MEMORIES_DIR" -name "*.md" -mtime -7 2>/dev/null | head -5)
  if [ -n "$RECENT" ]; then
    echo "🧠 Recent memories (last 7 days):"
    for f in $RECENT; do
      echo "  - $(basename "$f")"
    done
    echo "---"
  fi
fi

exit 0
