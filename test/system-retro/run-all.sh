#!/bin/bash
# Runs every numbered test in order; exits non-zero on first failure.
set -e
cd "$(dirname "$0")"
PASS=0; FAIL=0
for t in $(ls 0*.sh | sort); do
  if bash "$t"; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "FAIL: $t"; fi
done
echo ""
echo "system-retro tests: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
