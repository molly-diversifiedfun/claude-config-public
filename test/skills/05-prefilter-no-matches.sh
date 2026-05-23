#!/usr/bin/env bash
# Test: query 'xyzqwerty' matches nothing. Prefilter emits 'No matches found'
# sentinel and exits 0. Also covers kill switch as a sub-check.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

# Sub-check 1: no matches
cd ~/github/claude-config
OUT=$(bash "$PREFILTER" "xyzqwerty" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: no-match query should exit 0, got $RC" >&2
  echo "$OUT" >&2
  exit 1
fi

if ! echo "$OUT" | grep -qE "^# No matches found"; then
  echo "FAIL: expected 'No matches found' sentinel. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Sub-check 2: kill switch
OUT_KILL=$(SKILLS_CATALOG=off bash "$PREFILTER" "audit" 2>&1)
if ! echo "$OUT_KILL" | grep -qE "^# Catalog disabled"; then
  echo "FAIL: SKILLS_CATALOG=off should emit 'Catalog disabled'. Got:" >&2
  echo "$OUT_KILL" >&2
  exit 1
fi

echo "PASS"
