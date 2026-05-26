#!/usr/bin/env bash
# Test: manifest agents are NOT touched (no injection, no hijack).
# Phase 8.x.4: real agents load natively; hook must exit with empty output.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

for agent in builder creator strategist researcher operator product-lead designer debugger security reviewer content-qa memory-keeper; do
  echo "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$agent\",\"description\":\"test\",\"prompt\":\"hello\"}}" \
    | bash "$HOOK" 2>/dev/null > "$TMP"
  if [ ! -s "$TMP" ]; then
    PASS=$((PASS+1))
  else
    echo "FAIL: manifest agent '$agent' should NOT be touched by the hook"
    FAIL=$((FAIL+1))
  fi
done

echo "PASS: $PASS manifest agents correctly skipped"
echo "Test 05: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
