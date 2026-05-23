#!/usr/bin/env bash
# Test: a query with stopwords + a high-match term ('code') exercises both
# stopword stripping AND the 30-cap.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

cd ~/github/claude-config
OUT=$(bash "$PREFILTER" "the it is code" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: prefilter exited non-zero ($RC): $OUT" >&2
  exit 1
fi

# Count candidate lines (exclude header)
COUNT=$(echo "$OUT" | grep -cE '^[^#]' | tr -d ' ')
if [ "$COUNT" -gt 30 ]; then
  echo "FAIL: expected ≤30 candidates, got $COUNT" >&2
  echo "$OUT" >&2
  exit 1
fi

# The header should reflect cap behavior
HEADER=$(echo "$OUT" | grep -E "^# Candidates ")
if [ -z "$HEADER" ]; then
  echo "FAIL: missing candidates header. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

echo "PASS"
