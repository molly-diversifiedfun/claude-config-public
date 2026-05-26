#!/usr/bin/env bash
# Test: deprecated alias → full agent body injected in updatedInput.prompt.
# Phase 8.x.4: engineer→builder body, project-manager→operator body, content-social→creator body.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

fire() {
  echo "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$1\",\"description\":\"test\",\"prompt\":\"do the thing\"}}" | bash "$HOOK" 2>/dev/null > "$TMP"
}

# Assertion 1: engineer → builder body (contains /plan, /build, ship-a-feature)
fire "engineer"
PROMPT=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)
if echo "$PROMPT" | grep -q "/plan" && echo "$PROMPT" | grep -q "/build" && echo "$PROMPT" | grep -q "ship-a-feature"; then
  echo "PASS: engineer → builder body injected"; PASS=$((PASS+1))
else
  echo "FAIL: engineer missing builder identity markers"; FAIL=$((FAIL+1))
fi

# Assertion 2: project-manager → operator body (contains /deploy, deploy-project)
fire "project-manager"
PROMPT=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)
if echo "$PROMPT" | grep -q "/deploy" && echo "$PROMPT" | grep -q "deploy-project"; then
  echo "PASS: project-manager → operator body injected"; PASS=$((PASS+1))
else
  echo "FAIL: project-manager missing operator identity markers"; FAIL=$((FAIL+1))
fi

# Assertion 3: content-social → creator body (contains make-instagram-carousel)
fire "content-social"
PROMPT=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)
if echo "$PROMPT" | grep -q "make-instagram-carousel"; then
  echo "PASS: content-social → creator body injected"; PASS=$((PASS+1))
else
  echo "FAIL: content-social missing creator identity markers"; FAIL=$((FAIL+1))
fi

# Assertion 4: original prompt preserved at end
PROMPT=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)
if echo "$PROMPT" | grep -q "do the thing"; then
  echo "PASS: original prompt preserved in injection"; PASS=$((PASS+1))
else
  echo "FAIL: original prompt lost"; FAIL=$((FAIL+1))
fi

echo "Test 02: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
