#!/usr/bin/env bash
# Test 03: --enqueue writes a snapshot file containing all 4 required fields
# when prompt contains the Phase 7.5 marker block.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
mkdir -p "$AGENT_EVAL_QUEUE_DIR"

PROMPT='<!-- phase-7-5-injected-skills v1 -->
[Relevant skills for this task (Phase 7.5 prefilter):]
- humanize-ai-writing — Strip AI patterns
- voice-extractor — Extract a reusable voice profile
- brand-voice-router — Auto-detect brand voice

(Consider using one of these before reinventing.)
<!-- /phase-7-5-injected-skills -->

real task body goes here'

INPUT=$(jq -n --arg p "$PROMPT" '{tool_name:"Agent",tool_input:{subagent_type:"engineer",prompt:$p},tool_response:{content:"the agent did some work"}}')

echo "$INPUT" | bash "$HOOK" --enqueue 2>/dev/null
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1)); else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

QUEUE_FILES=("$AGENT_EVAL_QUEUE_DIR"/*.json)
if [ -f "${QUEUE_FILES[0]}" ]; then
  echo "PASS: queue file created"
  PASS=$((PASS+1))
  SNAP="${QUEUE_FILES[0]}"

  for field in subagent_type task injected_skills agent_return; do
    if jq -e ".${field}" "$SNAP" >/dev/null 2>&1; then
      echo "PASS: field $field present"; PASS=$((PASS+1))
    else echo "FAIL: field $field missing in $SNAP"; FAIL=$((FAIL+1)); fi
  done

  SKILL_COUNT=$(jq -r '.injected_skills | length' "$SNAP")
  if [ "$SKILL_COUNT" = "3" ]; then
    echo "PASS: 3 skills extracted"; PASS=$((PASS+1))
  else echo "FAIL: expected 3 skills, got $SKILL_COUNT"; FAIL=$((FAIL+1)); fi

  if jq -e '.injected_skills | index("humanize-ai-writing")' "$SNAP" >/dev/null 2>&1; then
    echo "PASS: humanize-ai-writing in skills list"; PASS=$((PASS+1))
  else echo "FAIL: humanize-ai-writing not extracted. Got: $(jq -c .injected_skills "$SNAP")"; FAIL=$((FAIL+1)); fi
else
  echo "FAIL: no queue file created"; FAIL=$((FAIL+1))
fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
