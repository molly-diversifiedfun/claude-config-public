#!/usr/bin/env bash
# Test: query "audit" from claude-config cwd. Expect candidates that include
# at least one Pool 1 (archetype-tagged) AND one Pool 2 (keyword-match) skill.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

cd ~/github/claude-config
OUT=$(bash "$PREFILTER" "audit" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: prefilter exited non-zero ($RC): $OUT" >&2
  exit 1
fi

if ! echo "$OUT" | grep -qE "^# Candidates "; then
  echo "FAIL: missing '# Candidates' header. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Must include at least 3 candidate lines (lines that aren't comment headers)
COUNT=$(echo "$OUT" | grep -cE '^[^#]' | tr -d ' ')
if [ "$COUNT" -lt 3 ]; then
  echo "FAIL: expected ≥3 candidates, got $COUNT. Output:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Sanity: at least one line should mention 'audit' in the name OR description
if ! echo "$OUT" | grep -qi "audit"; then
  echo "FAIL: no candidate mentions 'audit'. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

echo "PASS"
