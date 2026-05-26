#!/usr/bin/env bash
# Test: non-alias, non-manifest subagent_types → skipped (empty output).
# Phase 8.x.4: the hook only fires on the 7 deprecated aliases.
# Everything else (manifest agents, plugin agents, general-purpose) → exit 0, no output.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

fire() {
  echo "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$1\",\"description\":\"test\",\"prompt\":\"hello\"}}" | bash "$HOOK" 2>/dev/null > "$TMP"
  cat "$TMP"
}

# Assertion 1: general-purpose → skipped
fire "general-purpose" > /dev/null
if [ ! -s "$TMP" ]; then
  echo "PASS: general-purpose → no output"; PASS=$((PASS+1))
else
  echo "FAIL: general-purpose should be skipped"; FAIL=$((FAIL+1))
fi

# Assertion 2: planner (plugin agent) → skipped
fire "planner" > /dev/null
if [ ! -s "$TMP" ]; then
  echo "PASS: planner → no output"; PASS=$((PASS+1))
else
  echo "FAIL: planner should be skipped"; FAIL=$((FAIL+1))
fi

# Assertion 3: missing subagent_type → skipped
echo '{"tool_name":"Agent","tool_input":{"description":"test","prompt":"hello"}}' | bash "$HOOK" 2>/dev/null > "$TMP"
if [ ! -s "$TMP" ]; then
  echo "PASS: missing subagent_type → no output"; PASS=$((PASS+1))
else
  echo "FAIL: missing subagent_type should be skipped"; FAIL=$((FAIL+1))
fi

echo "Test 01: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
