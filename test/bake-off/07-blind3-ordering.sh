#!/usr/bin/env bash
# 07-blind3-ordering.sh — blind3 puts <3-appearance candidates BEFORE ≥3-appearance candidates
# Catches regressions in appearances_of, the UNTRIED/TRIED sort, or the head -3 cap.
set +e

SCRIPT="$HOME/.claude/scripts/bake-off-prefilter.sh"
PASS=0; FAIL=0

# Test isolation: mktemp -d + BAKEOFF_STATS_FILE override so the live stats
# file is NEVER touched (per feedback_test_fixtures_must_not_write_live_data_files.md).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"
STATS_TSV="$BAKEOFF_STATS_FILE"

# Get the real top-30 for our test query
PF_OUT=$(bash "$HOME/.claude/scripts/skills-prefilter.sh" "audit hook safety" 2>/dev/null \
         | grep -v '^#' | awk -F'|' 'NF>=2 {print $1}')
FIRST=$(echo "$PF_OUT" | sed -n '1p')
SECOND=$(echo "$PF_OUT" | sed -n '2p')
THIRD=$(echo "$PF_OUT" | sed -n '3p')

# Sanity: need at least 3 candidates for the test to mean anything
COUNT=$(echo "$PF_OUT" | wc -l | tr -d ' ')
if [ "$COUNT" -lt 4 ]; then
  echo "SKIP: need ≥4 candidates from skills-prefilter; got $COUNT"
  echo "Results: 0 passed, 0 failed"
  exit 0
fi

# === Case 1: seed FIRST + SECOND + THIRD with appearances=5 each ===
# Expected: blind3 puts OTHER (<3) candidates in slots A/B/C, NOT the seeded ones.
mkdir -p "$(dirname "$STATS_TSV")"
printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$STATS_TSV"
for s in "$FIRST" "$SECOND" "$THIRD"; do
  printf '%s\t5\t2\t3\t2026-01-01T00:00:00Z\n' "$s" >> "$STATS_TSV"
done

OUT=$(bash "$SCRIPT" "audit hook safety" 2>&1)
DATA=$(echo "$OUT" | grep -v '^#' | head -1)
A=$(echo "$DATA" | cut -d'|' -f2)
B=$(echo "$DATA" | cut -d'|' -f3)
C=$(echo "$DATA" | cut -d'|' -f4)

SEEDED_HIT=0
for slot_val in "$A" "$B" "$C"; do
  for seeded in "$FIRST" "$SECOND" "$THIRD"; do
    if [ "$slot_val" = "$seeded" ]; then
      SEEDED_HIT=1
    fi
  done
done

if [ "$SEEDED_HIT" = "0" ] && [ -n "$A" ] && [ -n "$B" ] && [ -n "$C" ]; then
  echo "PASS: case1 untried-first ordering — seeded skills ($FIRST/$SECOND/$THIRD) deprioritized; slots filled with A=$A B=$B C=$C"
  PASS=$((PASS+1))
else
  echo "FAIL: case1 expected NO seeded skills in slots A/B/C. Got A=$A B=$B C=$C (FIRST=$FIRST SECOND=$SECOND THIRD=$THIRD)"
  FAIL=$((FAIL+1))
fi

# === Case 2: ALL candidates seeded ≥3 → all are "tried" → fall through to prefilter order ===
# Expected: slot A == top-of-prefilter (or close — alphabetical-within-tier kicks in for ties)
printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$STATS_TSV"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  printf '%s\t5\t2\t3\t2026-01-01T00:00:00Z\n' "$name" >> "$STATS_TSV"
done <<< "$PF_OUT"

OUT=$(bash "$SCRIPT" "audit hook safety" 2>&1)
DATA=$(echo "$OUT" | grep -v '^#' | head -1)
A=$(echo "$DATA" | cut -d'|' -f2)
B=$(echo "$DATA" | cut -d'|' -f3)
C=$(echo "$DATA" | cut -d'|' -f4)

# All candidates seeded as TRIED — TRIED keeps prefilter order
# So slot A should be FIRST (top-of-prefilter-score)
if [ "$A" = "$FIRST" ] && [ -n "$B" ] && [ -n "$C" ]; then
  echo "PASS: case2 all-tried — slot A=$A is top-of-prefilter (B=$B C=$C)"
  PASS=$((PASS+1))
else
  echo "FAIL: case2 expected slot A == $FIRST. Got A=$A B=$B C=$C"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
