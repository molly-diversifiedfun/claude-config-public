#!/usr/bin/env bash
# Test: alias resolution works with empty description (prompt-only dispatch).
# Phase 8.x.4: body injection doesn't depend on description — only subagent_type matters.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Empty description, but valid alias → should still inject
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"tech-researcher","description":"","prompt":"research something"}}' \
  | bash "$HOOK" 2>/dev/null > "$TMP"

PROMPT=$(jq -r '.hookSpecificOutput.updatedInput.prompt // ""' "$TMP" 2>/dev/null)
if echo "$PROMPT" | grep -q "research-library"; then
  echo "PASS: tech-researcher with empty desc → researcher body injected"; PASS=$((PASS+1))
else
  echo "FAIL: tech-researcher should inject researcher body regardless of description"; FAIL=$((FAIL+1))
fi

echo "Test 04: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
