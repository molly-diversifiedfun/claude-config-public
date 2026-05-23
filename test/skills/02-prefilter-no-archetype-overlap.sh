#!/usr/bin/env bash
# Test: query "carousel" from claude-config (infra-config archetype). The term
# 'carousel' shouldn't dominate Pool 1 for infra-config, but Pool 2 should
# find carousel-writer (personal) or similar. Verify the prefilter doesn't
# crash when Pool 1 contributes little.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

cd ~/github/claude-config
OUT=$(bash "$PREFILTER" "carousel" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: prefilter exited non-zero ($RC): $OUT" >&2
  exit 1
fi

# Header must still print (either Candidates or No matches)
if ! echo "$OUT" | grep -qE "^# (Candidates|No matches)"; then
  echo "FAIL: expected header line. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

# If candidates found, at least one should mention carousel
if echo "$OUT" | grep -qE "^# Candidates"; then
  if ! echo "$OUT" | grep -qi "carousel"; then
    echo "FAIL: 'carousel' candidates section but no entry mentions carousel. Got:" >&2
    echo "$OUT" >&2
    exit 1
  fi
fi

echo "PASS"
