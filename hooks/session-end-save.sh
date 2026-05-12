#!/bin/bash
# session-end-save.sh — Stop hook
# Logs session end and backs up HANDOFF.md + TASKS.md

CHECKPOINT_DIR="$HOME/.claude/checkpoints"
BACKUP_DIR="$HOME/.claude/backups"
mkdir -p "$CHECKPOINT_DIR" "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Parse project dir from stdin JSON, fall back to cwd
INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "$TIMESTAMP | END | $PROJECT_DIR" >> "$CHECKPOINT_DIR/session-end.log"

# Backup HANDOFF.md and TASKS.md if they exist
if [ -f "$PROJECT_DIR/HANDOFF.md" ]; then
  cp "$PROJECT_DIR/HANDOFF.md" "$BACKUP_DIR/${PROJECT_NAME}-HANDOFF-$(date +%Y%m%d-%H%M%S).md" 2>/dev/null || true
fi
if [ -f "$PROJECT_DIR/TASKS.md" ]; then
  cp "$PROJECT_DIR/TASKS.md" "$BACKUP_DIR/${PROJECT_NAME}-TASKS-$(date +%Y%m%d-%H%M%S).md" 2>/dev/null || true
fi

# Prune backups older than 7 days
find "$BACKUP_DIR" -name "*.md" -mtime +7 -delete 2>/dev/null || true

exit 0
