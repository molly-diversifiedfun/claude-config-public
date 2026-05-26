#!/usr/bin/env bash
# Test: SKILL_INJECT_FOR_AGENT=off disables the hook entirely.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# With kill switch ON, engineer (a valid alias) should produce no output
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"test","prompt":"hello"}}' \
  | SKILL_INJECT_FOR_AGENT=off bash "$HOOK" 2>/dev/null > "$TMP"

if [ ! -s "$TMP" ]; then
  echo "PASS: kill switch → no output"; PASS=$((PASS+1))
else
  echo "FAIL: kill switch should suppress all output"; FAIL=$((FAIL+1))
fi

echo "Test 03: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
