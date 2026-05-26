#!/bin/bash
# mempalace-wrapper.sh — Forwards Claude Code hook events to the MemPalace CLI.
# Soft-fails open (exit 0 + empty JSON) if mempalace is missing or errors out,
# so a broken palace never breaks the harness. Per patterns A3 + A4 + B13:
# remind-only, instrumented, no exit-2 blocks.
#
# Usage:
#   mempalace-wrapper.sh --hook=<session-start|stop|precompact>
#
# Reads hook stdin JSON, forwards to `mempalace hook run --hook NAME --harness claude-code`,
# forwards stdout to harness, exits with the wrapped command's exit code.
# Always logs FIRED line with exit code to ~/.claude/logs/mempalace-hooks.log.

set -u
set -o pipefail

# Timeout cap (seconds) — prevents a hung mempalace from blocking the harness.
# Per reviewer M2: every SessionStart/Stop/Compact would block indefinitely otherwise.
MEMPALACE_TIMEOUT="${MEMPALACE_TIMEOUT:-10}"

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/mempalace-hooks.log"
mkdir -p "$LOG_DIR"

# Rotate log if >5MB (same pattern as observe-learning.sh)
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(stat -f '%z' "$LOG_FILE" 2>/dev/null || stat -c '%s' "$LOG_FILE" 2>/dev/null || echo "0")
  if [ "$LOG_SIZE" -gt 5242880 ]; then
    tail -5000 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
  fi
fi

# Parse --hook=NAME
HOOK_NAME=""
for arg in "$@"; do
  case "$arg" in
    --hook=*) HOOK_NAME="${arg#--hook=}" ;;
  esac
done

if [ -z "$HOOK_NAME" ]; then
  TS="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$TS] FIRED: unknown exit=0 reason=missing-hook-arg" >> "$LOG_FILE"
  echo "mempalace-wrapper: missing --hook=<name>" >&2
  echo '{}'
  exit 0
fi

# Buffer stdin (hook payload from Claude Code)
STDIN_BUF="$(cat)"

# Locate mempalace binary; soft-fail if absent
MEMPALACE_BIN="$(command -v mempalace 2>/dev/null || true)"
if [ -z "$MEMPALACE_BIN" ]; then
  TS="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$TS] FIRED: $HOOK_NAME exit=0 reason=mempalace-not-found" >> "$LOG_FILE"
  echo '{}'
  exit 0
fi

# Probe for a timeout binary — macOS lacks GNU timeout by default.
# Coreutils via brew installs `gtimeout`. Fall back to no-timeout if neither
# exists; we still soft-fail open per A3+B13 so a hang's blast radius is
# bounded to the current hook fire rather than the whole session.
TIMEOUT_BIN="$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"

# Run wrapped CLI, capture stdout + exit. `timeout` exits 124 on timeout.
if [ -n "$TIMEOUT_BIN" ]; then
  STDOUT_BUF="$(printf '%s' "$STDIN_BUF" | "$TIMEOUT_BIN" "$MEMPALACE_TIMEOUT" "$MEMPALACE_BIN" hook run --hook "$HOOK_NAME" --harness claude-code 2>>"$LOG_FILE")"
  EXIT_CODE=$?
else
  STDOUT_BUF="$(printf '%s' "$STDIN_BUF" | "$MEMPALACE_BIN" hook run --hook "$HOOK_NAME" --harness claude-code 2>>"$LOG_FILE")"
  EXIT_CODE=$?
fi

TS="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[$TS] FIRED: $HOOK_NAME exit=$EXIT_CODE" >> "$LOG_FILE"

# Forward stdout to harness first (so the user doesn't wait on memory-dir mining
# before the wake-up / transcript-save output lands). Mining happens after.
if [ -z "$STDOUT_BUF" ]; then
  echo '{}'
else
  printf '%s\n' "$STDOUT_BUF"
fi

# Phase 5 auto-mine (shipped 2026-05-19 NIGHT-8 after taxonomy cleanup).
# Walks ~/.claude/projects/*/memory/ dirs that contain mempalace.yaml and
# runs `mempalace mine <dir>` per dir. The CLI auto-discovers the yaml and
# uses its `wing:` value — so canonical wing names from Phase 5 land cleanly.
#
# Contract (soft-fail-open per patterns A3 + B13):
# - Fires ONLY on stop + precompact (NOT session-start — read-side stays lean)
# - Skips any dir without mempalace.yaml (intentional opt-out signal)
# - Skips any dir with `auto_mine: false` in its yaml (wrapper-only flag)
# - All mines run inside ONE background subshell, serialized internally
#   (mempalace palace uses a process-level file lock; parallel mines fail
#   with "palace is held by PID X" and exit 1 — serial ensures every dir lands)
# - Outer wall-clock cap = $MEMPALACE_TIMEOUT * 2 = 20s; watchdog kills lingerers
# - Each mine timeout-bounded individually via $TIMEOUT_BIN if available
# - All output → $LOG_FILE (stdout already flushed to harness above)
# - Every exit path → exit 0 below; never blocks the harness
if [ "$HOOK_NAME" = "stop" ] || [ "$HOOK_NAME" = "precompact" ]; then
  AUTO_MINE_TS="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$AUTO_MINE_TS] AUTO-MINE START: hook=$HOOK_NAME" >> "$LOG_FILE"
  AUTO_MINE_CAP=$(( MEMPALACE_TIMEOUT * 2 ))
  # Build dir list with workspace-github FIRST (Stage 11 captures + workspace
  # MEMORY.md land here — guarantees it mines even if watchdog kills the loop).
  AUTO_MINE_DIRS=()
  WORKSPACE_GITHUB_DIR="$HOME/.claude/projects/<your-workspace>/memory"
  if [ -d "$WORKSPACE_GITHUB_DIR" ] && [ -f "$WORKSPACE_GITHUB_DIR/mempalace.yaml" ]; then
    AUTO_MINE_DIRS+=("$WORKSPACE_GITHUB_DIR")
  fi
  for MEM_DIR in "$HOME"/.claude/projects/*/memory; do
    [ -d "$MEM_DIR" ] || continue
    [ -f "$MEM_DIR/mempalace.yaml" ] || continue
    # Skip the workspace-github dir — already at position 0
    [ "$MEM_DIR" = "$WORKSPACE_GITHUB_DIR" ] && continue
    AUTO_MINE_DIRS+=("$MEM_DIR")
  done
  (
    AUTO_MINE_COUNT=0
    for MEM_DIR in "${AUTO_MINE_DIRS[@]}"; do
      YAML="$MEM_DIR/mempalace.yaml"
      # Respect wrapper-only `auto_mine: false` flag (mempalace CLI ignores it)
      if grep -Eq '^[[:space:]]*auto_mine:[[:space:]]*false' "$YAML"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTO-MINE SKIP: $MEM_DIR reason=auto_mine-false" >> "$LOG_FILE"
        continue
      fi
      # No --wing flag: yaml-discovered wing wins (canonical name from Phase 5).
      if [ -n "$TIMEOUT_BIN" ]; then
        "$TIMEOUT_BIN" "$MEMPALACE_TIMEOUT" "$MEMPALACE_BIN" mine "$MEM_DIR" >>"$LOG_FILE" 2>&1
      else
        "$MEMPALACE_BIN" mine "$MEM_DIR" >>"$LOG_FILE" 2>&1
      fi
      MINE_RC=$?
      MINE_TS="$(date '+%Y-%m-%d %H:%M:%S')"
      if [ "$MINE_RC" -eq 0 ]; then
        echo "[$MINE_TS] AUTO-MINE OK: $MEM_DIR" >> "$LOG_FILE"
      else
        echo "[$MINE_TS] AUTO-MINE FAIL: $MEM_DIR exit=$MINE_RC" >> "$LOG_FILE"
      fi
      AUTO_MINE_COUNT=$((AUTO_MINE_COUNT + 1))
    done
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTO-MINE END: hook=$HOOK_NAME dirs=$AUTO_MINE_COUNT" >> "$LOG_FILE"
  ) &
  AUTO_MINE_LOOP_PID=$!
  # Watchdog: kill the entire mine loop if it exceeds the wall-clock cap.
  (
    sleep "$AUTO_MINE_CAP"
    if kill -0 "$AUTO_MINE_LOOP_PID" 2>/dev/null; then
      kill -TERM "$AUTO_MINE_LOOP_PID" 2>/dev/null
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTO-MINE WATCHDOG: killed loop pid=$AUTO_MINE_LOOP_PID cap=${AUTO_MINE_CAP}s" >> "$LOG_FILE"
    fi
  ) &
  WATCHDOG_PID=$!
  wait "$AUTO_MINE_LOOP_PID" 2>/dev/null || true
  kill -0 "$WATCHDOG_PID" 2>/dev/null && kill -TERM "$WATCHDOG_PID" 2>/dev/null
  wait "$WATCHDOG_PID" 2>/dev/null || true
fi

# Soft-fail open: never propagate non-zero from mempalace to the harness.
# Per A3 + B13 — remind-only initially. We have audit-trail in the log file.
exit 0
