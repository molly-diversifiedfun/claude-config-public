#!/usr/bin/env bash
# Test 08: drain moves snapshot to .failed/ after 2 parse failures, no JSONL row.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
export AGENT_EVAL_JSONL="$TMP/agent-eval.jsonl"
mkdir -p "$AGENT_EVAL_QUEUE_DIR/.failed"

mkdir -p "$TMP/bin"
cat > "$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
echo "still garbage no matter how many times you ask"
STUB
chmod +x "$TMP/bin/claude"
export PATH="$TMP/bin:$PATH"

SNAP_NAME="2026-05-21T15-00-00Z-222.json"
cat > "$AGENT_EVAL_QUEUE_DIR/$SNAP_NAME" <<JSON
{"ts":"2026-05-21T15:00:00Z","subagent_type":"engineer","task":"t","injected_skills":["a","b","c"],"agent_return":"r"}
JSON

bash "$HOOK" --drain 2>/dev/null
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0 (drain soft-fails open)"; PASS=$((PASS+1)); else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

REMAINING=$(find "$AGENT_EVAL_QUEUE_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" = "0" ]; then echo "PASS: snapshot removed from queue root"; PASS=$((PASS+1))
else echo "FAIL: snapshot still in queue root"; FAIL=$((FAIL+1)); fi

if [ -f "$AGENT_EVAL_QUEUE_DIR/.failed/$SNAP_NAME" ]; then
  echo "PASS: snapshot in .failed/"; PASS=$((PASS+1))
else echo "FAIL: snapshot not in .failed/. Contents: $(ls -la $AGENT_EVAL_QUEUE_DIR/.failed)"; FAIL=$((FAIL+1)); fi

if [ ! -s "$AGENT_EVAL_JSONL" ]; then echo "PASS: jsonl untouched"; PASS=$((PASS+1))
else echo "FAIL: jsonl unexpectedly written"; FAIL=$((FAIL+1)); fi

if grep -q '"outcome":"error:parse_failed_2x"' "$AGENT_EVAL_LOG_FILE" 2>/dev/null; then
  echo "PASS: log records parse_failed_2x"; PASS=$((PASS+1))
else echo "FAIL: log missing parse_failed_2x"; FAIL=$((FAIL+1)); fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
