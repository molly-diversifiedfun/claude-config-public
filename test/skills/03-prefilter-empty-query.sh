#!/usr/bin/env bash
# Test: empty query short-circuits with usage hint, exit 0.
# Also covers whitespace-only and all-stopword inputs.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

OUT=$(bash "$PREFILTER" "" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: empty query should exit 0, got $RC. Output:" >&2
  echo "$OUT" >&2
  exit 1
fi

if ! echo "$OUT" | grep -qE "^# Empty query"; then
  echo "FAIL: expected '# Empty query' usage hint. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Whitespace-only should also short-circuit
OUT2=$(bash "$PREFILTER" "   " 2>&1)
if ! echo "$OUT2" | grep -qE "^# Empty query"; then
  echo "FAIL: whitespace-only query should also short-circuit. Got:" >&2
  echo "$OUT2" >&2
  exit 1
fi

# All-stopword query should also short-circuit (Edit 1 from review)
OUT3=$(bash "$PREFILTER" "the it is" 2>&1)
if ! echo "$OUT3" | grep -qE "^# Empty query"; then
  echo "FAIL: all-stopword query should also short-circuit. Got:" >&2
  echo "$OUT3" >&2
  exit 1
fi

echo "PASS"
