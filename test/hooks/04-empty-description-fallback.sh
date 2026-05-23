#!/usr/bin/env bash
# Test: empty description, prompt contains query → hook uses prompt prefix and still fires.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0

# Empty description, prompt has the query
INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"","prompt":"humanize this paragraph and make it less AI"}}'
OUT=$(echo "$INPUT" | bash "$HOOK" 2>/dev/null)

# Assertion 1: still fires (uses prompt as fallback)
if [ -n "$OUT" ]; then
  echo "PASS: empty description + prompt with query → injection fires from prompt"
  PASS=$((PASS+1))
else
  echo "FAIL: should use prompt as fallback when description is empty"
  FAIL=$((FAIL+1))
fi

# Assertion 2: empty description AND empty prompt → no injection
INPUT2='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"","prompt":""}}'
OUT2=$(echo "$INPUT2" | bash "$HOOK" 2>/dev/null)
if [ -z "$OUT2" ]; then
  echo "PASS: empty description + empty prompt → no injection"
  PASS=$((PASS+1))
else
  echo "FAIL: empty description + empty prompt should not inject. Got: $OUT2"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
