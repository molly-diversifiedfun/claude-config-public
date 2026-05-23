#!/usr/bin/env bash
# Test: injection block is wrapped in stable HTML-comment markers (Phase 7.5.1)
# so Phase 7.6's enqueue mode can detect "was injected?" by sniffing the prompt.
set +e

HOOK="$HOME/.claude/hooks/inject-skills-for-agent.sh"
PASS=0; FAIL=0

INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","description":"humanize this paragraph","prompt":"original task"}}'
OUT=$(echo "$INPUT" | bash "$HOOK" 2>/dev/null)
INJECTED_PROMPT=$(echo "$OUT" | jq -r '.hookSpecificOutput.updatedInput.prompt // ""' 2>/dev/null)

# Assertion 1: opening marker present
if echo "$INJECTED_PROMPT" | grep -q '<!-- phase-7-5-injected-skills v1 -->'; then
  echo "PASS: opening marker present"
  PASS=$((PASS+1))
else
  echo "FAIL: missing opening marker. Got: $INJECTED_PROMPT"
  FAIL=$((FAIL+1))
fi

# Assertion 2: closing marker present
if echo "$INJECTED_PROMPT" | grep -q '<!-- /phase-7-5-injected-skills -->'; then
  echo "PASS: closing marker present"
  PASS=$((PASS+1))
else
  echo "FAIL: missing closing marker"
  FAIL=$((FAIL+1))
fi

# Assertion 3: original prompt still present after the block
if echo "$INJECTED_PROMPT" | grep -q "original task"; then
  echo "PASS: original prompt preserved after marker block"
  PASS=$((PASS+1))
else
  echo "FAIL: original prompt missing"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
