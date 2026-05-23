#!/usr/bin/env bash
# Test 09: AGENT_EVAL=off and AGENT_EVAL_DRAIN=off honored in both modes.
#
# Scenarios:
#   A. AGENT_EVAL=off + --enqueue       → no queue write, "skipped:kill_switch" logged
#   B. AGENT_EVAL=off + --drain         → seeded queue file untouched
#   C. AGENT_EVAL_DRAIN=off + --drain   → "skipped:drain_kill" logged
#   D. AGENT_EVAL_DRAIN=off + --enqueue → enqueue still runs (drain-only kill switch)
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
export AGENT_EVAL_JSONL="$TMP/agent-eval.jsonl"
mkdir -p "$AGENT_EVAL_QUEUE_DIR/.failed"

# Build a valid Phase-7.5-marker prompt for the enqueue scenarios.
# Em-dash (U+2014) is required as the bullet/desc separator in the marker block —
# pass via `jq -n --arg p` (NOT inline single-quoted JSON) so the bytes survive.
PROMPT='<!-- phase-7-5-injected-skills v1 -->
- a — desc
- b — desc
- c — desc
<!-- /phase-7-5-injected-skills -->
task'

INPUT=$(jq -n --arg p "$PROMPT" '{tool_name:"Agent",tool_input:{subagent_type:"engineer",prompt:$p},tool_response:{content:"r"}}')

# --- Scenario A: AGENT_EVAL=off disables enqueue ---
AGENT_EVAL=off bash "$HOOK" --enqueue <<< "$INPUT" 2>/dev/null

QUEUE_COUNT=$(find "$AGENT_EVAL_QUEUE_DIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [ "$QUEUE_COUNT" = "0" ]; then echo "PASS: AGENT_EVAL=off → no queue write"; PASS=$((PASS+1))
else echo "FAIL: AGENT_EVAL=off but queue has $QUEUE_COUNT files"; FAIL=$((FAIL+1)); fi

if grep -q '"mode":"enqueue".*"outcome":"skipped:kill_switch"' "$AGENT_EVAL_LOG_FILE" 2>/dev/null; then
  echo "PASS: log records enqueue kill_switch"; PASS=$((PASS+1))
else echo "FAIL: log missing enqueue kill_switch. Log: $(cat "$AGENT_EVAL_LOG_FILE" 2>/dev/null)"; FAIL=$((FAIL+1)); fi

# --- Scenario B: AGENT_EVAL=off disables drain ---
# Seed a queue file BEFORE invoking the kill switch so there's something to potentially consume.
SEED="$AGENT_EVAL_QUEUE_DIR/2026-05-21T15-00-00Z-999.json"
cat > "$SEED" <<JSON
{"ts":"2026-05-21T15:00:00Z","subagent_type":"engineer","task":"t","injected_skills":["a","b","c"],"agent_return":"r"}
JSON

AGENT_EVAL=off bash "$HOOK" --drain 2>/dev/null

if [ -f "$SEED" ]; then
  echo "PASS: AGENT_EVAL=off → queue file untouched by drain"; PASS=$((PASS+1))
else echo "FAIL: queue file consumed despite kill switch"; FAIL=$((FAIL+1)); fi

# --- Scenario C: AGENT_EVAL_DRAIN=off skips drain only ---
rm -f "$AGENT_EVAL_LOG_FILE"  # clean log for next assertion
AGENT_EVAL_DRAIN=off bash "$HOOK" --drain 2>/dev/null

if grep -q '"mode":"drain".*"outcome":"skipped:drain_kill"' "$AGENT_EVAL_LOG_FILE" 2>/dev/null; then
  echo "PASS: AGENT_EVAL_DRAIN=off → drain skipped"; PASS=$((PASS+1))
else echo "FAIL: drain_kill not logged. Log: $(cat "$AGENT_EVAL_LOG_FILE" 2>/dev/null)"; FAIL=$((FAIL+1)); fi

# --- Scenario D: AGENT_EVAL_DRAIN=off does NOT disable enqueue ---
rm -f "$AGENT_EVAL_QUEUE_DIR"/*.json 2>/dev/null
AGENT_EVAL_DRAIN=off bash "$HOOK" --enqueue <<< "$INPUT" 2>/dev/null

QUEUE_AFTER=$(find "$AGENT_EVAL_QUEUE_DIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [ "$QUEUE_AFTER" = "1" ]; then
  echo "PASS: AGENT_EVAL_DRAIN=off → enqueue still runs"; PASS=$((PASS+1))
else echo "FAIL: enqueue not running. Queue: $QUEUE_AFTER. Log: $(cat "$AGENT_EVAL_LOG_FILE" 2>/dev/null)"; FAIL=$((FAIL+1)); fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
