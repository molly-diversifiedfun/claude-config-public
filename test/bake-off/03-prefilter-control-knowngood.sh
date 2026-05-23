#!/usr/bin/env bash
# 03-prefilter-control-knowngood.sh — control2 picks highest-win-rate ≥3-appearance candidate,
# falls back to top-of-prefilter-score when none qualify.
set +e

SCRIPT="$HOME/.claude/scripts/bake-off-prefilter.sh"
PASS=0; FAIL=0

# Test isolation: mktemp -d + BAKEOFF_STATS_FILE override so the live stats
# file is NEVER touched (per feedback_test_fixtures_must_not_write_live_data_files.md).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"
STATS_TSV="$BAKEOFF_STATS_FILE"

PF_OUT=$(bash "$HOME/.claude/scripts/skills-prefilter.sh" "audit hook safety" 2>/dev/null \
         | grep -v '^#' | awk -F'|' 'NF>=2 {print $1}')
TOP_SCORE=$(echo "$PF_OUT" | head -1)
SECOND=$(echo "$PF_OUT" | sed -n '2p')
THIRD=$(echo "$PF_OUT" | sed -n '3p')

# === Case 1: Fallback path — empty stats, known-good = top-of-prefilter-score ===
mkdir -p "$(dirname "$STATS_TSV")"
printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$STATS_TSV"

OUT=$(bash "$SCRIPT" "--control audit hook safety" 2>&1)
DATA=$(echo "$OUT" | grep -v '^#' | head -1)
MODE=$(echo "$DATA" | cut -d'|' -f1)
KNOWN_GOOD=$(echo "$DATA" | cut -d'|' -f2)
YOLO_PICK=$(echo "$DATA" | cut -d'|' -f3)

if [ "$MODE" = "control2" ] && [ "$KNOWN_GOOD" = "$TOP_SCORE" ] && [ -n "$YOLO_PICK" ] && [ "$YOLO_PICK" != "$KNOWN_GOOD" ]; then
  echo "PASS: case1 fallback known-good=$KNOWN_GOOD, yolo=$YOLO_PICK (no collision)"
  PASS=$((PASS+1))
else
  echo "FAIL: case1 expected known-good=$TOP_SCORE + non-empty yolo ≠ known-good. Got: $DATA"
  FAIL=$((FAIL+1))
fi

# === Case 2: Historical-data path — SECOND has 5/2, THIRD has 1/3 → known-good = SECOND ===
printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$STATS_TSV"
printf '%s\t7\t5\t2\t2026-01-01T00:00:00Z\n' "$SECOND" >> "$STATS_TSV"
printf '%s\t4\t1\t3\t2026-01-01T00:00:00Z\n' "$THIRD" >> "$STATS_TSV"

OUT=$(bash "$SCRIPT" "--control audit hook safety" 2>&1)
DATA=$(echo "$OUT" | grep -v '^#' | head -1)
KNOWN_GOOD=$(echo "$DATA" | cut -d'|' -f2)
YOLO_PICK=$(echo "$DATA" | cut -d'|' -f3)

if [ "$KNOWN_GOOD" = "$SECOND" ] && [ -n "$YOLO_PICK" ] && [ "$YOLO_PICK" != "$KNOWN_GOOD" ]; then
  echo "PASS: case2 historical known-good=$SECOND (5/7), yolo=$YOLO_PICK"
  PASS=$((PASS+1))
else
  echo "FAIL: case2 expected known-good=$SECOND. Got: $DATA"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
