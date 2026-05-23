#!/usr/bin/env bash
# Test: composite_score() rescale math correct in both jaccard_only and full modes.
# Invokes via --composite-test CLI flag which reads "desc_j|body_j|losses_n|elim_n|jaccard_only" from stdin
# and prints the score formatted to 3 decimals.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0

OUT1=$(echo "0.20|0.60|0|0|true" | python3 "$SCRIPT" --composite-test 2>/dev/null)
RC1=$?

if [ "$RC1" -eq 0 ]; then echo "PASS: jaccard_only exit 0"; PASS=$((PASS+1))
else echo "FAIL: jaccard_only exit $RC1"; FAIL=$((FAIL+1)); fi

if [ "$OUT1" = "0.345" ]; then echo "PASS: jaccard_only=true → 0.345"; PASS=$((PASS+1))
else echo "FAIL: jaccard_only=true got '$OUT1', expected 0.345"; FAIL=$((FAIL+1)); fi

OUT2=$(echo "0.20|0.60|0|0|false" | python3 "$SCRIPT" --composite-test 2>/dev/null)
RC2=$?

if [ "$RC2" -eq 0 ]; then echo "PASS: full-mode exit 0"; PASS=$((PASS+1))
else echo "FAIL: full-mode exit $RC2"; FAIL=$((FAIL+1)); fi

if [ "$OUT2" = "0.190" ]; then echo "PASS: jaccard_only=false → 0.190"; PASS=$((PASS+1))
else echo "FAIL: jaccard_only=false got '$OUT2', expected 0.190"; FAIL=$((FAIL+1)); fi

echo "Test 11: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
