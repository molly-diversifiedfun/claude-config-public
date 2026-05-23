#!/usr/bin/env bash
# Test 02: --enqueue skips when prompt lacks the Phase 7.5 marker.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
mkdir -p "$AGENT_EVAL_QUEUE_DIR"

# engineer (allowlisted) but no marker in prompt
INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"engineer","prompt":"plain task with no marker"},"tool_response":{"content":"result"}}'

echo "$INPUT" | bash "$HOOK" --enqueue 2>/dev/null
RC=$?

if [ "$RC" -eq 0 ]; then
  echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

QUEUE_COUNT=$(find "$AGENT_EVAL_QUEUE_DIR" -type f | wc -l | tr -d ' ')
if [ "$QUEUE_COUNT" = "0" ]; then
  echo "PASS: queue empty"; PASS=$((PASS+1))
else echo "FAIL: queue has $QUEUE_COUNT files"; FAIL=$((FAIL+1)); fi

if grep -q '"outcome":"skipped:not_injected"' "$AGENT_EVAL_LOG_FILE" 2>/dev/null; then
  echo "PASS: log records skipped:not_injected"; PASS=$((PASS+1))
else echo "FAIL: log missing not_injected"; FAIL=$((FAIL+1)); fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
