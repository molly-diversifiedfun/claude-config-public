#!/bin/bash
# synthesize-learnings.sh — SessionStart hook
# Checks if new feedback memory files exist that haven't been processed into learned/ patterns.
# Outputs a system message prompting Claude to synthesize if gaps found.
# This hook DOES NOT auto-generate files — it flags the need for Claude to do it.

LEARNED_DIR="$HOME/.claude/skills/learned"
MEMORY_DIRS=(
  "$HOME/.claude/projects/-Users-molly-shelestak-github/memory"
  "$HOME/.claude/projects/-Users-molly-shelestak-github-content-system/memory"
  "$HOME/.claude/projects/-Users-molly-shelestak-github-unstuckwithmolly/memory"
  "$HOME/.claude/projects/-Users-molly-shelestak-github-ship-it-system/memory"
  "$HOME/.claude/projects/-Users-molly-shelestak-github-<your-project-2>/memory"
  "$HOME/.claude/projects/-Users-molly-shelestak-github-moa-debate/memory"
  "$HOME/.claude/projects/-Users-molly-shelestak-github-gig-analyzer-dash/memory"
)

mkdir -p "$LEARNED_DIR"

# Reset tool counter at session start so retrospective checks are session-scoped
COUNTER_FILE="$HOME/.claude/checkpoints/.tool_count"
echo "0" > "$COUNTER_FILE"

# Get newest learned file timestamp (epoch seconds)
NEWEST_LEARNED=0
if [ -d "$LEARNED_DIR" ]; then
  for f in "$LEARNED_DIR"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "SKILL.md" ] && continue
    TS=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "0")
    [ "$TS" -gt "$NEWEST_LEARNED" ] && NEWEST_LEARNED=$TS
  done
fi

# Count feedback files newer than newest learned
NEW_FEEDBACK=0
NEW_FILES=""
for dir in "${MEMORY_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  for f in "$dir"/feedback_*.md; do
    [ -f "$f" ] || continue
    TS=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "0")
    if [ "$TS" -gt "$NEWEST_LEARNED" ]; then
      NEW_FEEDBACK=$((NEW_FEEDBACK + 1))
      NEW_FILES="$NEW_FILES $(basename "$f")"
    fi
  done
done

if [ "$NEW_FEEDBACK" -gt 0 ]; then
  echo "{\"systemMessage\":\"LEARNING GAP: $NEW_FEEDBACK new feedback files since last learned/ update:$NEW_FILES. Consider reading these and updating ~/.claude/skills/learned/ patterns.\"}"
else
  echo '{}'
fi

exit 0
