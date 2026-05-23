#!/usr/bin/env bash
# Test: engineer subagent with a description matching a real skill → injection contains the skill name.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0

# Fire hook with engineer + humanize-related description
INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"humanize this paragraph","prompt":""}}'
OUT=$(echo "$INPUT" | bash "$HOOK" 2>/dev/null)

# Assertion 1: output is non-empty
if [ -n "$OUT" ]; then
  echo "PASS: engineer + humanize description → non-empty injection"
  PASS=$((PASS+1))
else
  echo "FAIL: engineer + humanize description should produce non-empty output"
  FAIL=$((FAIL+1))
fi

# Assertion 2: extract the modified prompt from the JSON output and check for humanize-ai-writing
INJECTED_PROMPT=$(echo "$OUT" | jq -r '.hookSpecificOutput.updatedInput.prompt // ""' 2>/dev/null)
if echo "$INJECTED_PROMPT" | grep -q "humanize-ai-writing"; then
  echo "PASS: injection contains humanize-ai-writing"
  PASS=$((PASS+1))
else
  echo "FAIL: injection should contain humanize-ai-writing. Got injected prompt: $INJECTED_PROMPT"
  FAIL=$((FAIL+1))
fi

# Assertion 3: injected prompt contains exactly 3 skill bullets
BULLETS=$(echo "$INJECTED_PROMPT" | grep -cE '^- ')
if [ "$BULLETS" -eq 3 ]; then
  echo "PASS: injection contains exactly 3 skill bullets"
  PASS=$((PASS+1))
else
  echo "FAIL: expected 3 bullets, got $BULLETS. Injected prompt: $INJECTED_PROMPT"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
