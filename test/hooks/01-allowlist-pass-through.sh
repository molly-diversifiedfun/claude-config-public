#!/usr/bin/env bash
# Test: non-allowlist subagent_types do NOT trigger injection.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0

# Helper: fire hook with given JSON, capture stdout
fire() {
  local subagent="$1"
  local desc="${2:-something}"
  echo "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$subagent\",\"description\":\"$desc\",\"prompt\":\"\"}}" | bash "$HOOK" 2>/dev/null
}

# Assertion 1: project-manager → no injection
OUT=$(fire "project-manager")
if [ -z "$OUT" ]; then
  echo "PASS: project-manager subagent_type → no injection (output empty)"
  PASS=$((PASS+1))
else
  echo "FAIL: project-manager subagent_type should not inject. Got: $OUT"
  FAIL=$((FAIL+1))
fi

# Assertion 2: memory-keeper → no injection
OUT=$(fire "memory-keeper")
if [ -z "$OUT" ]; then
  echo "PASS: memory-keeper subagent_type → no injection"
  PASS=$((PASS+1))
else
  echo "FAIL: memory-keeper should not inject. Got: $OUT"
  FAIL=$((FAIL+1))
fi

# Assertion 3: missing subagent_type → no injection (safe default)
OUT=$(echo '{"tool_name":"Agent","tool_input":{"description":"something","prompt":""}}' | bash "$HOOK" 2>/dev/null)
if [ -z "$OUT" ]; then
  echo "PASS: missing subagent_type → no injection"
  PASS=$((PASS+1))
else
  echo "FAIL: missing subagent_type should not inject. Got: $OUT"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
