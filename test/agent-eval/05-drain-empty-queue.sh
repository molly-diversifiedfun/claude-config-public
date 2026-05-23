#!/usr/bin/env bash
# Test 05: --drain no-ops cleanly on empty queue.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
export AGENT_EVAL_JSONL="$TMP/agent-eval.jsonl"
mkdir -p "$AGENT_EVAL_QUEUE_DIR"

bash "$HOOK" --drain 2>/dev/null
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1)); else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if grep -q '"outcome":"drain:empty"' "$AGENT_EVAL_LOG_FILE" 2>/dev/null; then
  echo "PASS: log records drain:empty"; PASS=$((PASS+1))
else echo "FAIL: log missing drain:empty"; FAIL=$((FAIL+1)); fi

# JSONL should not exist (or be empty) — we never wrote a row
if [ ! -s "$AGENT_EVAL_JSONL" ]; then
  echo "PASS: jsonl not written"; PASS=$((PASS+1))
else echo "FAIL: jsonl unexpectedly has content"; FAIL=$((FAIL+1)); fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
