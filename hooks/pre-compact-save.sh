#!/bin/bash
# pre-compact-save.sh — PreToolUse hook (matcher: Compact)
# Before compaction: backup files, commit changes, mark HANDOFF.md

CHECKPOINT_DIR="$HOME/.claude/checkpoints"
BACKUP_DIR="$HOME/.claude/backups"
mkdir -p "$CHECKPOINT_DIR" "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Parse project dir from stdin JSON, fall back to cwd
INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Log compaction event
echo "$TIMESTAMP | PRE-COMPACT | $PROJECT_DIR" >> "$CHECKPOINT_DIR/activity.jsonl"

# Backup HANDOFF.md and TASKS.md
if [ -f "$PROJECT_DIR/HANDOFF.md" ]; then
  cp "$PROJECT_DIR/HANDOFF.md" "$BACKUP_DIR/${PROJECT_NAME}-HANDOFF-precompact-$(date +%Y%m%d-%H%M%S).md" 2>/dev/null || true
fi
if [ -f "$PROJECT_DIR/TASKS.md" ]; then
  cp "$PROJECT_DIR/TASKS.md" "$BACKUP_DIR/${PROJECT_NAME}-TASKS-precompact-$(date +%Y%m%d-%H%M%S).md" 2>/dev/null || true
fi

# If in a git repo, commit any uncommitted changes
if [ -d "$PROJECT_DIR/.git" ]; then
  cd "$PROJECT_DIR" || exit 0
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    git add -A 2>/dev/null
    git commit -m "[pre-compact] Auto-save before context compaction - $TIMESTAMP" 2>/dev/null || \
    git stash push -m "pre-compact auto-stash $TIMESTAMP" 2>/dev/null || true
  fi
fi

# Append compaction marker to HANDOFF.md if it exists
if [ -f "$PROJECT_DIR/HANDOFF.md" ]; then
  echo "" >> "$PROJECT_DIR/HANDOFF.md"
  echo "---" >> "$PROJECT_DIR/HANDOFF.md"
  echo "⚠️ Context compacted at $TIMESTAMP. Re-read this file for ground truth." >> "$PROJECT_DIR/HANDOFF.md"
fi

exit 0
