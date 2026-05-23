#!/usr/bin/env bash
# Test: SKILL_INJECT_FOR_AGENT=off disables the hook entirely.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0

INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"humanize this paragraph","prompt":""}}'

# Assertion 1: with kill switch on, no injection
OUT_OFF=$(echo "$INPUT" | SKILL_INJECT_FOR_AGENT=off bash "$HOOK" 2>/dev/null)
if [ -z "$OUT_OFF" ]; then
  echo "PASS: SKILL_INJECT_FOR_AGENT=off → no injection"
  PASS=$((PASS+1))
else
  echo "FAIL: kill switch should suppress injection. Got: $OUT_OFF"
  FAIL=$((FAIL+1))
fi

# Assertion 2: without kill switch, injection fires (regression guard for accidental always-off)
OUT_ON=$(echo "$INPUT" | bash "$HOOK" 2>/dev/null)
if [ -n "$OUT_ON" ]; then
  echo "PASS: without kill switch, injection fires"
  PASS=$((PASS+1))
else
  echo "FAIL: without kill switch, injection should fire"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
