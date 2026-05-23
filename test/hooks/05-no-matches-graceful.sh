#!/usr/bin/env bash
# Test: a description that matches NO skills → exit 0, no injection, no error.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0

# Nonsense query
INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"xyzqwerty zzznopopo","prompt":""}}'
OUT=$(echo "$INPUT" | bash "$HOOK" 2>/dev/null)
EXIT=$?

# Assertion 1: exit code is 0 (never block dispatch on no-matches)
if [ "$EXIT" = "0" ]; then
  echo "PASS: no-matches case exits 0 (does not block)"
  PASS=$((PASS+1))
else
  echo "FAIL: no-matches case exited $EXIT (expected 0)"
  FAIL=$((FAIL+1))
fi

# Assertion 2: no injection output
if [ -z "$OUT" ]; then
  echo "PASS: no-matches case → empty stdout"
  PASS=$((PASS+1))
else
  echo "FAIL: no-matches case should not inject. Got: $OUT"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
