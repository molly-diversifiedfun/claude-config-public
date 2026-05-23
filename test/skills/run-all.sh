#!/usr/bin/env bash
# Run all skills-prefilter unit tests, report PASS/FAIL summary.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

for t in "$DIR"/[0-9][0-9]-*.sh; do
  name=$(basename "$t")
  printf "%-50s " "$name"
  if bash "$t" > /dev/null 2>&1; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    bash "$t" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
