#!/usr/bin/env bash
# Test: Phase 7.2.1 — Pool 2 scoring sorts by distinct-keyword-match count desc.
# Query "fix a bash bug" (keywords: fix/bash/bug after stopword strip) should
# rank superpowers:systematic-debugging (matches 'bug' + 'debug'-prefix) at top.
# Pre-7.2.1 (alphabetical sort), `claude-code-setup:...` would have led
# because of alphabetical-A ordering.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

cd ~/github/claude-config
OUT=$(bash "$PREFILTER" "fix a bash bug" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: prefilter exited non-zero ($RC): $OUT" >&2
  exit 1
fi

# Extract the first non-header line (top candidate)
TOP=$(echo "$OUT" | grep -vE '^#' | head -1)

# Top candidate should be a debugging skill (systematic-debugging is the highest
# scorer because its description mentions 'bug'/'failure'/'unexpected').
if ! echo "$TOP" | grep -qE "^(superpowers:systematic-debugging|.*debug)"; then
  echo "FAIL: expected top candidate to be debug-related. Got:" >&2
  echo "$TOP" >&2
  echo "Full output:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Score-sort sanity: top 5 should contain at least 2 of: debugging/debug/bug/fix
TOP5=$(echo "$OUT" | grep -vE '^#' | head -5)
HITS=$(echo "$TOP5" | grep -ciE "debug|bug-|fix|bash|verification" | tr -d ' ')
if [ "$HITS" -lt 2 ]; then
  echo "FAIL: top 5 should contain ≥2 debug/bug/fix-related skills. Got $HITS:" >&2
  echo "$TOP5" >&2
  exit 1
fi

echo "PASS"
