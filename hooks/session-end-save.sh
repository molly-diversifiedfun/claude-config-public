#!/bin/bash
# session-end-save.sh — Stop hook
# Logs session end and backs up HANDOFF.md + TASKS.md
# Rate-limited: max 1 backup per project per 10 minutes (prevents subagent-exit flood)

CHECKPOINT_DIR="$HOME/.claude/checkpoints"
BACKUP_DIR="$HOME/.claude/backups"
mkdir -p "$CHECKPOINT_DIR" "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Parse project dir from stdin JSON, fall back to cwd
INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

SESSION_LOG="$CHECKPOINT_DIR/session-end.log"
echo "$TIMESTAMP | END | $PROJECT_DIR" >> "$SESSION_LOG"

# Rotate session-end.log if >500KB
if [ -f "$SESSION_LOG" ]; then
  LOG_SIZE=$(stat -f '%z' "$SESSION_LOG" 2>/dev/null || echo "0")
  if [ "$LOG_SIZE" -gt 512000 ]; then
    tail -1000 "$SESSION_LOG" > "$SESSION_LOG.tmp" 2>/dev/null && mv "$SESSION_LOG.tmp" "$SESSION_LOG" 2>/dev/null
  fi
fi

# Rate limit: skip if we backed up this project in the last 10 minutes
SENTINEL_DIR="$CHECKPOINT_DIR/.backup-sentinels"
mkdir -p "$SENTINEL_DIR" 2>/dev/null
SENTINEL="$SENTINEL_DIR/$PROJECT_NAME"
if [ -f "$SENTINEL" ]; then
  SENTINEL_AGE=$(( $(date +%s) - $(stat -f %m "$SENTINEL" 2>/dev/null || echo 0) ))
  if [ "$SENTINEL_AGE" -lt 600 ]; then
    exit 0
  fi
fi
touch "$SENTINEL" 2>/dev/null

# Backup HANDOFF.md and TASKS.md if they exist
if [ -f "$PROJECT_DIR/HANDOFF.md" ]; then
  cp "$PROJECT_DIR/HANDOFF.md" "$BACKUP_DIR/${PROJECT_NAME}-HANDOFF-$(date +%Y%m%d-%H%M%S).md" 2>/dev/null || true
fi
if [ -f "$PROJECT_DIR/TASKS.md" ]; then
  cp "$PROJECT_DIR/TASKS.md" "$BACKUP_DIR/${PROJECT_NAME}-TASKS-$(date +%Y%m%d-%H%M%S).md" 2>/dev/null || true
fi

# Prune backups older than 3 days
find "$BACKUP_DIR" -name "*.md" -mtime +3 -delete 2>/dev/null || true

exit 0
