#!/usr/bin/env bash
# Test 07: drain retries once on bad JSON, then succeeds.
# Stub returns garbage on first call, valid JSON on second call.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
export AGENT_EVAL_JSONL="$TMP/agent-eval.jsonl"
mkdir -p "$AGENT_EVAL_QUEUE_DIR/.failed"

# Stub claude — call counter via temp file
mkdir -p "$TMP/bin"
CALLS_FILE="$TMP/calls"
echo 0 > "$CALLS_FILE"

cat > "$TMP/bin/claude" <<STUB
#!/usr/bin/env bash
cat >/dev/null
N=\$(cat "$CALLS_FILE")
N=\$((N+1))
echo "\$N" > "$CALLS_FILE"
if [ "\$N" -eq 1 ]; then
  echo "this is not valid json"
else
  echo '{"used_injected_skill":false,"which_skill":null,"better_skill_suggested":null,"quality_score":3,"rationale":"adequate"}'
fi
STUB
chmod +x "$TMP/bin/claude"
export PATH="$TMP/bin:$PATH"

cat > "$AGENT_EVAL_QUEUE_DIR/2026-05-21T15-00-00Z-111.json" <<JSON
{"ts":"2026-05-21T15:00:00Z","subagent_type":"engineer","task":"t","injected_skills":["a","b","c"],"agent_return":"r"}
JSON

bash "$HOOK" --drain 2>/dev/null
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1)); else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

CALLS=$(cat "$CALLS_FILE")
if [ "$CALLS" = "2" ]; then echo "PASS: claude called exactly twice (1 fail + 1 retry)"; PASS=$((PASS+1))
else echo "FAIL: expected 2 claude calls, got $CALLS"; FAIL=$((FAIL+1)); fi

ROW_COUNT=$(wc -l < "$AGENT_EVAL_JSONL" 2>/dev/null | tr -d ' ')
if [ "$ROW_COUNT" = "1" ]; then echo "PASS: 1 row in JSONL after retry"; PASS=$((PASS+1))
else echo "FAIL: expected 1 row, got $ROW_COUNT"; FAIL=$((FAIL+1)); fi

FAILED_COUNT=$(find "$AGENT_EVAL_QUEUE_DIR/.failed" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [ "$FAILED_COUNT" = "0" ]; then echo "PASS: nothing in .failed/"; PASS=$((PASS+1))
else echo "FAIL: .failed/ has $FAILED_COUNT files"; FAIL=$((FAIL+1)); fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
