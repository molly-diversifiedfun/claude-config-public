#!/usr/bin/env bash
# Test: empty corpus → exit 0 + "no skills found" message + no report file.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/empty" "$TMP/reports"

OUT=$(SKILL_CONSOLIDATE_ROOTS="$TMP/empty" \
      BAKEOFF_LOG_FILE="$TMP/n.jsonl" \
      BAKEOFF_STATS_FILE="$TMP/n.tsv" \
      REPORT_DIR="$TMP/reports" \
      python3 "$SCRIPT" 2>&1)
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if echo "$OUT" | grep -qi 'no skills found'; then echo "PASS: 'no skills found' message"; PASS=$((PASS+1))
else echo "FAIL: missing message. Got: $OUT"; FAIL=$((FAIL+1)); fi

if [ -z "$(ls "$TMP/reports" 2>/dev/null)" ]; then echo "PASS: no report file"; PASS=$((PASS+1))
else echo "FAIL: report file unexpectedly created"; FAIL=$((FAIL+1)); fi

echo "Test 07: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
