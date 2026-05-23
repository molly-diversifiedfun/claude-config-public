#!/usr/bin/env bash
# Test 04: snapshotted task field does NOT contain the Phase 7.5 marker block.
# The judge should see the real task, not our scaffolding.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
mkdir -p "$AGENT_EVAL_QUEUE_DIR"

PROMPT='<!-- phase-7-5-injected-skills v1 -->
[Relevant skills for this task (Phase 7.5 prefilter):]
- skill-a — desc A
- skill-b — desc B
- skill-c — desc C
<!-- /phase-7-5-injected-skills -->

CLEAN_TASK_MARKER refactor the foo bar baz'

INPUT=$(jq -n --arg p "$PROMPT" '{tool_name:"Agent",tool_input:{subagent_type:"engineer",prompt:$p},tool_response:{content:"x"}}')

echo "$INPUT" | bash "$HOOK" --enqueue 2>/dev/null

SNAP=$(ls "$AGENT_EVAL_QUEUE_DIR"/*.json 2>/dev/null | head -1)
if [ -n "$SNAP" ]; then
  TASK=$(jq -r '.task' "$SNAP")

  if echo "$TASK" | grep -q "phase-7-5-injected-skills"; then
    echo "FAIL: marker still in task. Task: $TASK"; FAIL=$((FAIL+1))
  else
    echo "PASS: marker stripped from task"; PASS=$((PASS+1))
  fi

  if echo "$TASK" | grep -q "CLEAN_TASK_MARKER"; then
    echo "PASS: real task body preserved"; PASS=$((PASS+1))
  else echo "FAIL: real task missing. Task: $TASK"; FAIL=$((FAIL+1)); fi
else
  echo "FAIL: no snapshot file"; FAIL=$((FAIL+1))
fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
