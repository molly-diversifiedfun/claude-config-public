#!/usr/bin/env bash
set -e
DIR="$HOME/.claude/test/archetype-injector"
PASS=0; FAIL=0
for t in "$DIR"/[0-9]*.sh; do
  printf "%-50s " "$(basename "$t")"
  if "$t" >/dev/null 2>&1; then
    echo "PASS"
    PASS=$((PASS+1))
  else
    echo "FAIL"
    FAIL=$((FAIL+1))
    "$t" 2>&1 | sed 's/^/    /'
  fi
done
echo
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
