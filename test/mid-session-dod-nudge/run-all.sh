#!/bin/bash
# Tests for mid-session-dod-nudge.sh — fires when count>=threshold + HANDOFF stale + sentinel absent.
set -e
HOOK="$HOME/.claude/hooks/mid-session-dod-nudge.sh"

setup_tmp() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/sentinels" "$TMP/proj"
  echo "150" > "$TMP/counter"  # default: above threshold
  # HANDOFF stale by 2 days
  echo "# stale" > "$TMP/proj/HANDOFF.md"
  touch -t 202605210000 "$TMP/proj/HANDOFF.md"
  export NUDGE_COUNTER_FILE="$TMP/counter"
  export NUDGE_SENTINEL_DIR="$TMP/sentinels"
  export NUDGE_TODAY="2026-05-23"
  export NUDGE_PROJECT_ROOT="$TMP/proj"
}
cleanup() { unset NUDGE_COUNTER_FILE NUDGE_SENTINEL_DIR NUDGE_TODAY NUDGE_PROJECT_ROOT MID_SESSION_NUDGE NUDGE_THRESHOLD; rm -rf "$TMP" 2>/dev/null; }

# 01 — kill switch
setup_tmp
OUT=$(MID_SESSION_NUDGE=off bash "$HOOK" < /dev/null)
[ "$OUT" = "" ] || { echo "01-kill-switch: FAIL — expected empty, got: $OUT"; exit 1; }
echo "01-kill-switch: OK"
cleanup

# 02 — below threshold = no nudge
setup_tmp
echo "50" > "$TMP/counter"
OUT=$(bash "$HOOK" < /dev/null)
[ "$OUT" = "{}" ] || { echo "02-below-threshold: FAIL — expected {}, got: $OUT"; exit 1; }
echo "02-below-threshold: OK"
cleanup

# 03 — HANDOFF fresh today = no nudge
setup_tmp
touch -t 202605231200 "$TMP/proj/HANDOFF.md"  # today
OUT=$(bash "$HOOK" < /dev/null)
[ "$OUT" = "{}" ] || { echo "03-handoff-fresh: FAIL — expected {}, got: $OUT"; exit 1; }
echo "03-handoff-fresh: OK"
cleanup

# 04 — sentinel exists (already nudged today) = no nudge
setup_tmp
touch "$TMP/sentinels/.dod_nudge_2026-05-23"
OUT=$(bash "$HOOK" < /dev/null)
[ "$OUT" = "{}" ] || { echo "04-sentinel-exists: FAIL — expected {}, got: $OUT"; exit 1; }
echo "04-sentinel-exists: OK"
cleanup

# 05 — happy path: count >= threshold + stale HANDOFF + no sentinel = nudge + sentinel created
setup_tmp
OUT=$(bash "$HOOK" < /dev/null)
echo "$OUT" | grep -q "DoD nudge" || { echo "05-nudge: FAIL — expected DoD nudge in output: $OUT"; exit 1; }
echo "$OUT" | grep -q "hookSpecificOutput" || { echo "05-nudge: FAIL — expected hook envelope: $OUT"; exit 1; }
[ -f "$TMP/sentinels/.dod_nudge_2026-05-23" ] || { echo "05-nudge: FAIL — sentinel not created"; exit 1; }
echo "05-nudge: OK"
cleanup

# 06 — second invocation same day = no nudge (sentinel was created)
setup_tmp
bash "$HOOK" < /dev/null > /dev/null  # first invocation creates sentinel
OUT=$(bash "$HOOK" < /dev/null)        # second invocation should no-op
[ "$OUT" = "{}" ] || { echo "06-once-per-day: FAIL — expected {}, got: $OUT"; exit 1; }
echo "06-once-per-day: OK"
cleanup

# 07 — missing counter file = no nudge (treat as fresh session)
setup_tmp
rm "$TMP/counter"
OUT=$(bash "$HOOK" < /dev/null)
[ "$OUT" = "{}" ] || { echo "07-missing-counter: FAIL — expected {}, got: $OUT"; exit 1; }
echo "07-missing-counter: OK"
cleanup

echo ""
echo "mid-session-dod-nudge tests: 7 passed, 0 failed"
