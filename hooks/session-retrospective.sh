#!/bin/bash
# session-retrospective.sh — Stop hook (redesigned 2026-05-26)
# Grace mechanism: first miss = soft nudge, 2+ consecutive = block.
# Checks: HANDOFF.md freshness + TASKS.md freshness (the two that matter).
# Outputs JSON: {} to allow, {"decision":"block",...} to block.
# Kill switch: RETROSPECTIVE_GATE=off → exit 0 with {} (no-op).

if [ "${RETROSPECTIVE_GATE:-on}" = "off" ]; then
  echo '{}'
  exit 0
fi

source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null || true

COUNTER_FILE="$HOME/.claude/checkpoints/.tool_count"
MISS_FILE="$HOME/.claude/checkpoints/.dod_consecutive_misses"

# Resolve PROJECT_ROOT — outermost ancestor with HANDOFF.md + memory dir
MAX_ANCESTOR_LEVELS=5
PROJECT_ROOT=""
if [ -n "${CLAUDE_WORKSPACE_ROOT:-}" ] && [ -d "$CLAUDE_WORKSPACE_ROOT" ]; then
  PROJECT_ROOT="$CLAUDE_WORKSPACE_ROOT"
else
  DIR="$PWD"
  for _ in $(seq 0 "$MAX_ANCESTOR_LEVELS"); do
    if [ -f "$DIR/HANDOFF.md" ]; then
      CAND_KEY=$(echo "$DIR" | sed 's|[/.]|-|g')
      if [ -d "$HOME/.claude/projects/${CAND_KEY}/memory" ]; then
        PROJECT_ROOT="$DIR"
      fi
    fi
    PARENT=$(dirname "$DIR")
    [ "$PARENT" = "$DIR" ] && break
    DIR="$PARENT"
  done
fi
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
fi

HANDOFF="$PROJECT_ROOT/HANDOFF.md"
TASKS="$PROJECT_ROOT/TASKS.md"

# Low activity sessions — always allow, reset miss counter
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
fi
if [ "$COUNT" -lt 20 ]; then
  echo '{}'
  exit 0
fi

TODAY=$(date +%Y-%m-%d)
REASONS=""

# CHECK 1: HANDOFF.md freshness
if [ -f "$HANDOFF" ]; then
  HANDOFF_MOD=$(stat -f '%Sm' -t '%Y-%m-%d' "$HANDOFF" 2>/dev/null || date +%Y-%m-%d)
  if [ "$HANDOFF_MOD" != "$TODAY" ]; then
    REASONS="${REASONS}HANDOFF.md not updated today. "
  fi
else
  REASONS="${REASONS}No HANDOFF.md found. "
fi

# CHECK 2: TASKS.md freshness
if [ -f "$TASKS" ]; then
  TASKS_MOD=$(stat -f '%Sm' -t '%Y-%m-%d' "$TASKS" 2>/dev/null || date +%Y-%m-%d)
  if [ "$TASKS_MOD" != "$TODAY" ]; then
    REASONS="${REASONS}TASKS.md not updated today. "
  fi
fi

# GRACE MECHANISM
if [ -z "$REASONS" ]; then
  # All checks pass — reset consecutive miss counter
  echo "0" > "$MISS_FILE" 2>/dev/null
  echo '{}'
  exit 0
fi

# Something missed — read consecutive miss count
MISSES=0
if [ -f "$MISS_FILE" ]; then
  MISSES=$(cat "$MISS_FILE" 2>/dev/null || echo "0")
fi
MISSES=$((MISSES + 1))
echo "$MISSES" > "$MISS_FILE" 2>/dev/null

if [ "$MISSES" -le 1 ]; then
  # First miss: soft nudge (systemMessage, not block)
  echo "{\"systemMessage\":\"DoD nudge (miss 1): ${REASONS}Update before next session end or it will block. Kill: RETROSPECTIVE_GATE=off\"}"
  exit 0
fi

# 2+ consecutive misses: hard block
REASONS_ESCAPED=$(echo "$REASONS" | sed 's/"/\\"/g')
type log_block >/dev/null 2>&1 && log_block "Stop hook block: DoD INCOMPLETE (${MISSES} consecutive): $REASONS" ""
echo "{\"decision\":\"block\",\"reason\":\"DoD INCOMPLETE (${MISSES} consecutive misses): ${REASONS_ESCAPED}Update HANDOFF.md and TASKS.md before ending session. Kill: RETROSPECTIVE_GATE=off\"}"
exit 0
