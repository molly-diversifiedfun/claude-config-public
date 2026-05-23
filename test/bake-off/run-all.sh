#!/usr/bin/env bash
# run-all.sh — run all bake-off tests, report aggregate
set +e

DIR="$(dirname "$0")"
TESTS=(
  "$DIR/01-prefilter-modes.sh"
  "$DIR/02-prefilter-yolo-fallback.sh"
  "$DIR/03-prefilter-control-knowngood.sh"
  "$DIR/04-recorder-atomicity.sh"
  "$DIR/05-recorder-mode-columns.sh"
  "$DIR/06-kill-switch.sh"
  "$DIR/07-blind3-ordering.sh"
  "$DIR/08-eliminated-dropped.sh"
)

TOTAL_PASS=0
TOTAL_FAIL=0
for t in "${TESTS[@]}"; do
  echo "=== $(basename "$t") ==="
  OUT=$(bash "$t" 2>&1)
  echo "$OUT"
  RESULTS=$(echo "$OUT" | grep '^Results:' | tail -1)
  P=$(echo "$RESULTS" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
  F=$(echo "$RESULTS" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)
  TOTAL_PASS=$((TOTAL_PASS + P))
  TOTAL_FAIL=$((TOTAL_FAIL + F))
  echo
done

echo "=========================================="
echo "Results: $TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
