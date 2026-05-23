#!/usr/bin/env bash
# Aggregator for Phase 7.7a.4 /merge-skills tests. Mirrors test/consolidate-skills/run-all.sh.
set +e
cd "$(dirname "$0")"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_TESTS=()

for t in $(ls [0-9][0-9]-*.sh 2>/dev/null | sort); do
  echo "=== $t ==="
  bash "$t"
  RC=$?
  if [ "$RC" -eq 0 ]; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("$t")
  fi
  echo ""
done

echo "================================"
echo "Total: $TOTAL_PASS pass / $TOTAL_FAIL fail"
if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo "Failed: ${FAILED_TESTS[*]}"
  exit 1
fi
exit 0
