#!/usr/bin/env bash
# run-all.sh — run all hook tests, aggregate per-test "Results: N passed, M failed" lines.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

for t in "$DIR"/[0-9][0-9]-*.sh; do
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
