#!/usr/bin/env bash
# 02-prefilter-yolo-fallback.sh — yolo picks <3-appearance, falls back to top-30 if none
set +e

SCRIPT="$HOME/.claude/scripts/bake-off-prefilter.sh"
PASS=0; FAIL=0

# Test isolation: mktemp -d + BAKEOFF_STATS_FILE override so the live stats
# file is NEVER touched (per feedback_test_fixtures_must_not_write_live_data_files.md).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"
STATS_TSV="$BAKEOFF_STATS_FILE"

# === Case 1: empty stats → yolo picks from <3 (which is everything) ===
mkdir -p "$(dirname "$STATS_TSV")"
printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$STATS_TSV"

OUT=$(bash "$SCRIPT" "--yolo audit hook safety" 2>&1)
DATA=$(echo "$OUT" | grep -v '^#' | head -1)
PICK=$(echo "$DATA" | cut -d'|' -f2)
if [ -n "$PICK" ] && [ "$(echo "$DATA" | cut -d'|' -f1)" = "yolo1" ]; then
  echo "PASS: case1 yolo picks from empty-stats pool ($PICK)"; PASS=$((PASS+1))
else
  echo "FAIL: case1 expected non-empty yolo pick, got: $DATA"; FAIL=$((FAIL+1))
fi

# === Case 2: all top-30 candidates have ≥3 appearances → fallback to random-from-top-30 ===
# Seed stats: write 30 dummy candidates with appearances=3.
# Get the top-30 prefilter output for this query first.
PF_OUT=$(bash "$HOME/.claude/scripts/skills-prefilter.sh" "audit hook safety" 2>/dev/null \
         | grep -v '^#' | awk -F'|' 'NF>=2 {print $1}')
printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$STATS_TSV"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  printf '%s\t3\t1\t1\t2026-01-01T00:00:00Z\n' "$name" >> "$STATS_TSV"
done <<< "$PF_OUT"

OUT=$(bash "$SCRIPT" "--yolo audit hook safety" 2>&1)
DATA=$(echo "$OUT" | grep -v '^#' | head -1)
PICK=$(echo "$DATA" | cut -d'|' -f2)
if [ -n "$PICK" ] && [ "$(echo "$DATA" | cut -d'|' -f1)" = "yolo1" ]; then
  if echo "$PF_OUT" | grep -qx "$PICK"; then
    echo "PASS: case2 yolo fallback picks from top-30 ($PICK)"; PASS=$((PASS+1))
  else
    echo "FAIL: case2 fallback pick ($PICK) not in top-30"; FAIL=$((FAIL+1))
  fi
else
  echo "FAIL: case2 expected non-empty yolo fallback, got: $DATA"; FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
