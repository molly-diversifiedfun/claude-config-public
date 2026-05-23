#!/usr/bin/env bash
# Test 06: --drain processes 1 queue file end-to-end with stubbed claude -p.
# Verifies: claude -p invoked, valid JSON parsed, eval row written to JSONL, queue file removed.
set +e

HOOK="$HOME/.claude/hooks/agent-eval.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
export AGENT_EVAL_QUEUE_DIR="$TMP/queue"
export AGENT_EVAL_LOG_FILE="$TMP/agent-eval.log"
export AGENT_EVAL_JSONL="$TMP/agent-eval.jsonl"
mkdir -p "$AGENT_EVAL_QUEUE_DIR/.failed"

# Stub claude binary
mkdir -p "$TMP/bin"
cat > "$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
cat <<'JSON'
{"used_injected_skill":true,"which_skill":"humanize-ai-writing","better_skill_suggested":null,"quality_score":4,"rationale":"Agent applied skill"}
JSON
STUB
chmod +x "$TMP/bin/claude"
export PATH="$TMP/bin:$PATH"

# Seed one queue file
cat > "$AGENT_EVAL_QUEUE_DIR/2026-05-21T15-00-00Z-123456.json" <<JSON
{
  "ts": "2026-05-21T15:00:00Z",
  "subagent_type": "engineer",
  "task": "humanize this paragraph",
  "injected_skills": ["humanize-ai-writing","voice-extractor","brand-voice-router"],
  "agent_return": "Rewrote with shorter sentences and cut filler words."
}
JSON

bash "$HOOK" --drain 2>/dev/null
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1)); else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

ROW_COUNT=$(wc -l < "$AGENT_EVAL_JSONL" 2>/dev/null | tr -d ' ')
if [ "$ROW_COUNT" = "1" ]; then
  echo "PASS: 1 row in JSONL"; PASS=$((PASS+1))
else echo "FAIL: expected 1 row, got $ROW_COUNT"; FAIL=$((FAIL+1)); fi

if jq -e '.judgment.quality_score == 4 and .judgment.which_skill == "humanize-ai-writing"' "$AGENT_EVAL_JSONL" >/dev/null 2>&1; then
  echo "PASS: judgment fields populated correctly"; PASS=$((PASS+1))
else echo "FAIL: judgment fields wrong. Row: $(cat "$AGENT_EVAL_JSONL")"; FAIL=$((FAIL+1)); fi

REMAINING=$(find "$AGENT_EVAL_QUEUE_DIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [ "$REMAINING" = "0" ]; then
  echo "PASS: queue file removed after processing"; PASS=$((PASS+1))
else echo "FAIL: queue file not removed ($REMAINING remaining)"; FAIL=$((FAIL+1)); fi

FAILED_COUNT=$(find "$AGENT_EVAL_QUEUE_DIR/.failed" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [ "$FAILED_COUNT" = "0" ]; then
  echo "PASS: nothing in .failed/"; PASS=$((PASS+1))
else echo "FAIL: .failed/ unexpectedly has $FAILED_COUNT files"; FAIL=$((FAIL+1)); fi

rm -rf "$TMP"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
