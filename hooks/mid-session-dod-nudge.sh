#!/bin/bash
# Phase 8.0 follow-up — Mid-session DoD nudge.
#
# Addresses /system-retro Phase 7.7c finding that 'Deferred DoD' was the
# #2 recurring gap across 20 sessions. Stop hook (session-retrospective.sh)
# already enforces DoD at session end, but by then the deferral has already
# happened. This nudge fires earlier — once per day, when the tool counter
# crosses 100 AND HANDOFF.md is stale — as a soft systemMessage (NOT a
# block) so the user can update HANDOFF.md while there's still context room.
#
# Once-per-day to avoid nag fatigue. Sentinel: ~/.claude/checkpoints/.dod_nudge_<YYYY-MM-DD>.
# Soft-fails open on every internal error.
#
# Kill switch: MID_SESSION_NUDGE=off
set -e

[ "${MID_SESSION_NUDGE:-on}" = "off" ] && exit 0

emit_nothing() { echo '{}'; exit 0; }
emit_ctx() { jq -n --arg ctx "$1" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'; exit 0; }

# Drain stdin so the parent isn't blocked
cat >/dev/null || true

CHECKPOINT_DIR="${NUDGE_SENTINEL_DIR:-$HOME/.claude/checkpoints}"
COUNTER_FILE="${NUDGE_COUNTER_FILE:-$HOME/.claude/checkpoints/.tool_count}"
TODAY="${NUDGE_TODAY:-$(date +%Y-%m-%d)}"
SENTINEL="$CHECKPOINT_DIR/.dod_nudge_$TODAY"

# Threshold for "you've been working a while" — matches CARL context bracket
# MODERATE threshold so we nudge at the same point context tightens
NUDGE_THRESHOLD="${NUDGE_THRESHOLD:-100}"

# Already nudged today — silent
[ -f "$SENTINEL" ] && emit_nothing

# Need a counter to know whether we've been working
[ -f "$COUNTER_FILE" ] || emit_nothing
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
[ "$COUNT" -ge "$NUDGE_THRESHOLD" ] || emit_nothing

# Ancestor-walk for HANDOFF.md (same logic as session-retrospective.sh so we
# point at the right file when cwd is a sub-repo). Walks up to 5 levels.
# Test override: NUDGE_PROJECT_ROOT bypasses the walk entirely.
if [ -n "$NUDGE_PROJECT_ROOT" ]; then
  PROJECT_ROOT="$NUDGE_PROJECT_ROOT"
else
  MAX_ANCESTOR_LEVELS=5
  PROJECT_ROOT=""
  DIR="$PWD"
  for _ in $(seq 0 "$MAX_ANCESTOR_LEVELS"); do
    if [ -f "$DIR/HANDOFF.md" ]; then
      CAND_KEY=$(echo "$DIR" | sed 's|[/.]|-|g')
      if [ -d "$HOME/.claude/projects/${CAND_KEY}/memory" ]; then
        PROJECT_ROOT="$DIR"
        break
      fi
    fi
    PARENT=$(dirname "$DIR")
    [ "$PARENT" = "$DIR" ] && break
    DIR="$PARENT"
  done
  [ -z "$PROJECT_ROOT" ] && PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
fi

HANDOFF="$PROJECT_ROOT/HANDOFF.md"
[ -f "$HANDOFF" ] || emit_nothing

HANDOFF_DATE=$(stat -f '%Sm' -t '%Y-%m-%d' "$HANDOFF" 2>/dev/null || echo "")
[ "$HANDOFF_DATE" = "$TODAY" ] && emit_nothing  # fresh; no nudge needed

# All conditions met — nudge once, mark sentinel.
mkdir -p "$CHECKPOINT_DIR" 2>/dev/null
touch "$SENTINEL" 2>/dev/null

NUDGE="🪜 DoD nudge: you've made $COUNT tool calls today and $HANDOFF was last updated $HANDOFF_DATE (not today). Consider updating HANDOFF.md now while context is healthy — the Stop hook will block at session end if it's still stale. Kill: export MID_SESSION_NUDGE=off"

emit_ctx "$NUDGE"
