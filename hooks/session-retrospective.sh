#!/bin/bash
# session-retrospective.sh — Stop hook
# Blocks session end if DoD items are incomplete.
# Checks: HANDOFF.md, TASKS.md, learnings, enforcement, tests, docs.
# Outputs JSON: {} to allow, {"decision":"block","reason":"..."} to block.

COUNTER_FILE="$HOME/.claude/checkpoints/.tool_count"
ACTIVITY_LOG="$HOME/.claude/checkpoints/activity.jsonl"

# Ancestor-walk to find PROJECT_ROOT: nearest dir with BOTH HANDOFF.md AND a
# configured memory dir under ~/.claude/projects/. Falls back to git root, then PWD.
# Prevents cwd drift into a sub-repo from triggering false-positive
# "HANDOFF stale" / "no learnings" when the workspace HANDOFF/memory live one
# or more levels up. See feedback_cwd_drift_breaks_stop_hook_dod.md.
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

# Fallback chain: git root → PWD
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
fi

# Derive project memory dir from resolved PROJECT_ROOT
PROJECT_KEY=$(echo "$PROJECT_ROOT" | sed 's|[/.]|-|g')
MEMORY_DIR="$HOME/.claude/projects/${PROJECT_KEY}/memory"
HANDOFF="$PROJECT_ROOT/HANDOFF.md"
TASKS="$PROJECT_ROOT/TASKS.md"

# Check tool count
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
fi

# Low activity sessions — allow without checks
if [ "$COUNT" -lt 20 ]; then
  echo '{}'
  exit 0
fi

TODAY=$(date +%Y-%m-%d)
REASONS=""

# ============================================================
# CHECK 1: HANDOFF.md freshness
# ============================================================
HANDOFF_STALE=false
if [ -f "$HANDOFF" ]; then
  HANDOFF_MOD=$(stat -f '%Sm' -t '%Y-%m-%d' "$HANDOFF" 2>/dev/null || date +%Y-%m-%d)
  if [ "$HANDOFF_MOD" != "$TODAY" ]; then
    HANDOFF_STALE=true
  fi
else
  HANDOFF_STALE=true
fi

if [ "$HANDOFF_STALE" = "true" ]; then
  REASONS="${REASONS}HANDOFF.md not updated today. "
fi

# ============================================================
# CHECK 2: TASKS.md freshness (if it exists)
# ============================================================
if [ -f "$TASKS" ]; then
  TASKS_MOD=$(stat -f '%Sm' -t '%Y-%m-%d' "$TASKS" 2>/dev/null || date +%Y-%m-%d)
  if [ "$TASKS_MOD" != "$TODAY" ]; then
    REASONS="${REASONS}TASKS.md not updated today ($COUNT tool uses in session). "
  fi
fi

# ============================================================
# CHECK 3: Learnings saved to memory
# ============================================================
LEARNINGS_SAVED=false
if [ -d "$MEMORY_DIR" ]; then
  RECENT=$(find "$MEMORY_DIR" -name "*.md" -newermt "$TODAY" 2>/dev/null | head -1)
  if [ -n "$RECENT" ]; then
    LEARNINGS_SAVED=true
  fi
fi

if [ "$LEARNINGS_SAVED" = "false" ]; then
  REASONS="${REASONS}No learnings saved to memory ($COUNT tool uses). "
fi

# ============================================================
# CHECK 4: Enforcement created (if learnings saved + commits made)
# ============================================================
ENFORCEMENT_CREATED=false
ENFORCEMENT_LOCATIONS=(
  "$HOME/.claude/hooks"
  "$HOME/.claude/rules"
  "$HOME/.claude/skills/learned"
  "$PROJECT_ROOT/eslint.config.js"
  "$PROJECT_ROOT/vitest.config.ts"
  "$PROJECT_ROOT/biome.json"
  "$HOME/.carl"
)
for loc in "${ENFORCEMENT_LOCATIONS[@]}"; do
  if [ -e "$loc" ]; then
    if [ -d "$loc" ]; then
      MODIFIED=$(find "$loc" -name "*.sh" -o -name "*.md" -o -name "*.json" | xargs stat -f '%Sm %N' -t '%Y-%m-%d' 2>/dev/null | grep "^$TODAY" | head -1)
    else
      MOD_DATE=$(stat -f '%Sm' -t '%Y-%m-%d' "$loc" 2>/dev/null || echo "")
      if [ "$MOD_DATE" = "$TODAY" ]; then
        MODIFIED="$loc"
      fi
    fi
    if [ -n "$MODIFIED" ]; then
      ENFORCEMENT_CREATED=true
      break
    fi
  fi
done

COMMITS_TODAY=$(git -C "$PROJECT_ROOT" log --oneline --since="$TODAY" 2>/dev/null | wc -l | tr -d ' ')
if [ "$LEARNINGS_SAVED" = "true" ] && [ "$ENFORCEMENT_CREATED" = "false" ] && [ "$COMMITS_TODAY" -gt 0 ]; then
  REASONS="${REASONS}Learnings saved but no enforcement created (hook/rule/config/learned). "
fi

# ============================================================
# CHECK 5: Tests run (if commits were made today)
# ============================================================
if [ "$COMMITS_TODAY" -gt 0 ] && [ -f "$ACTIVITY_LOG" ]; then
  # Look for test commands in today's activity
  TESTS_RUN=$(grep "$TODAY" "$ACTIVITY_LOG" 2>/dev/null | grep -i 'npm.*test\|vitest\|jest\|pytest\|playwright' | head -1)
  if [ -z "$TESTS_RUN" ]; then
    REASONS="${REASONS}$COMMITS_TODAY commit(s) today but no test run found in activity log. "
  fi
fi

# ============================================================
# CHECK 6: Lint run (if commits were made today)
# ============================================================
if [ "$COMMITS_TODAY" -gt 0 ] && [ -f "$ACTIVITY_LOG" ]; then
  LINT_RUN=$(grep "$TODAY" "$ACTIVITY_LOG" 2>/dev/null | grep -i 'npm run check\|biome\|eslint\|tsc --noEmit' | head -1)
  if [ -z "$LINT_RUN" ]; then
    REASONS="${REASONS}$COMMITS_TODAY commit(s) today but no lint/type check found in activity log. "
  fi
fi

# ============================================================
# CHECK 7: Agent output verification (if agents were used)
# ============================================================
if [ -f "$ACTIVITY_LOG" ]; then
  AGENTS_TODAY=$(grep "$TODAY" "$ACTIVITY_LOG" 2>/dev/null | grep '"tool":"Agent"' | wc -l | tr -d ' ')
  if [ "$AGENTS_TODAY" -gt 0 ]; then
    # Check if Read was used after the last Agent call (proxy for "reviewed output")
    LAST_AGENT_TS=$(grep "$TODAY" "$ACTIVITY_LOG" 2>/dev/null | grep '"tool":"Agent"' | tail -1 | grep -o '"ts":"[^"]*"' | head -1)
    READS_AFTER=$(grep "$TODAY" "$ACTIVITY_LOG" 2>/dev/null | grep '"tool":"Read"' | grep -c "$(echo "$LAST_AGENT_TS" | cut -c7-16)" 2>/dev/null || echo "0")
    # This is a heuristic — if no Reads happened in the same minute window as/after the last Agent, flag it
    if [ "$AGENTS_TODAY" -gt 2 ] && [ "$READS_AFTER" -lt 1 ]; then
      REASONS="${REASONS}$AGENTS_TODAY agent invocations today — verify agent output was reviewed before staging. "
    fi
  fi
fi

# ============================================================
# DECISION
# ============================================================
if [ -n "$REASONS" ]; then
  REASONS_ESCAPED=$(echo "$REASONS" | sed 's/"/\\"/g')
  echo "{\"decision\":\"block\",\"reason\":\"DoD INCOMPLETE: ${REASONS_ESCAPED}Walk the Definition of Done (rules/common/definition-of-done.md) before ending session.\"}"
  exit 0
fi

# All checks pass
echo '{"systemMessage":"DoD verified: HANDOFF current, TASKS updated, learnings saved, enforcement created, tests run, lint passed."}'
exit 0
