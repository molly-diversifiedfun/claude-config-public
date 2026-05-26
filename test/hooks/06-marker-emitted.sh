#!/usr/bin/env bash
# Test: alias injection includes the DEPRECATED ALIAS marker comment.
# Phase 8.x.4: the marker tells the orchestrator which alias was used and what it resolved to.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Fire engineer alias
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"x","prompt":"y"}}' \
  | bash "$HOOK" 2>/dev/null > "$TMP"

PROMPT=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)

# Assertion 1: marker present
if echo "$PROMPT" | grep -q "<!-- DEPRECATED ALIAS: 'engineer' resolved to 'builder'"; then
  echo "PASS: DEPRECATED ALIAS marker present with correct mapping"; PASS=$((PASS+1))
else
  echo "FAIL: missing or incorrect DEPRECATED ALIAS marker"; FAIL=$((FAIL+1))
fi

# Assertion 2: marker contains the correct target
if echo "$PROMPT" | grep -q "Use subagent_type='builder' in future dispatches"; then
  echo "PASS: marker includes guidance to use the new name"; PASS=$((PASS+1))
else
  echo "FAIL: marker missing guidance text"; FAIL=$((FAIL+1))
fi

# Assertion 3: all 7 aliases produce a marker
for alias in engineer content-social content-longform content-business tech-researcher market-researcher project-manager; do
  echo "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$alias\",\"description\":\"x\",\"prompt\":\"y\"}}" \
    | bash "$HOOK" 2>/dev/null > "$TMP"
  P=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)
  if echo "$P" | grep -q "<!-- DEPRECATED ALIAS:"; then
    PASS=$((PASS+1))
  else
    echo "FAIL: alias '$alias' missing DEPRECATED ALIAS marker"
    FAIL=$((FAIL+1))
  fi
done

echo "Test 06: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
