#!/usr/bin/env bash
# Test 01: --enqueue skips dispatches to non-allowlisted subagent_type.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

# Isolated data dirs via env-var override (per feedback_test_fixtures_must_not_write_live_data_files)
TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
mkdir -p "$AGENT_EVAL_QUEUE_DIR"

# project-manager is NOT in the allowlist
INPUT='{"tool_name":"Agent","tool_input":{"subagent_type":"project-manager","prompt":"<!-- phase-7-5-injected-skills v1 -->\nfoo\n<!-- /phase-7-5-injected-skills -->\n\nreal task"},"tool_response":{"content":"result"}}'

echo "$INPUT" | bash "$HOOK" --enqueue 2>/dev/null
RC=$?

# Assertion 1: exit 0
if [ "$RC" -eq 0 ]; then
  echo "PASS: exit 0 on non-allowlisted subagent"
  PASS=$((PASS+1))
else
  echo "FAIL: expected exit 0, got $RC"
  FAIL=$((FAIL+1))
fi

# Assertion 2: queue dir empty (no snapshot written)
QUEUE_COUNT=$(find "$AGENT_EVAL_QUEUE_DIR" -type f | wc -l | tr -d ' ')
if [ "$QUEUE_COUNT" = "0" ]; then
  echo "PASS: queue dir empty after non-allowlisted dispatch"
  PASS=$((PASS+1))
else
  echo "FAIL: expected empty queue, got $QUEUE_COUNT files"
  FAIL=$((FAIL+1))
fi

# Assertion 3: log line records skipped:not_allowlisted
if grep -q '"outcome":"skipped:not_allowlisted"' "$AGENT_EVAL_LOG_FILE" 2>/dev/null; then
  echo "PASS: log records skipped:not_allowlisted"
  PASS=$((PASS+1))
else
  echo "FAIL: log missing skipped:not_allowlisted. Log content: $(cat "$AGENT_EVAL_LOG_FILE" 2>/dev/null)"
  FAIL=$((FAIL+1))
fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
