#!/usr/bin/env bash
# Test: judge_pair() invokes JUDGE_CLAUDE_CMD, parses valid JSON, retries once on bad JSON.
# Uses --judge-pair <pathA> <pathB> CLI debug flag.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/sA" "$TMP/user/sB"
cat > "$TMP/user/sA/SKILL.md" <<'EOF'
---
name: sA
description: skill A
---
A body content
EOF
cat > "$TMP/user/sB/SKILL.md" <<'EOF'
---
name: sB
description: skill B
---
B body content
EOF

# Happy-path mock: always returns valid JSON
cat > "$TMP/mock-happy.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"overlap": true, "confidence": 5, "rationale": "Mock rationale text."}'
EOF
chmod +x "$TMP/mock-happy.sh"

OUT_HAPPY=$(JUDGE_CLAUDE_CMD="$TMP/mock-happy.sh" \
            JUDGE_FAILURE_DIR="$TMP/failures" \
            python3 "$SCRIPT" --judge-pair "$TMP/user/sA/SKILL.md" "$TMP/user/sB/SKILL.md" 2>/dev/null)
RC_HAPPY=$?

if [ "$RC_HAPPY" -eq 0 ]; then echo "PASS: --judge-pair happy exits 0"; PASS=$((PASS+1))
else echo "FAIL: --judge-pair happy exit $RC_HAPPY"; FAIL=$((FAIL+1)); fi

if echo "$OUT_HAPPY" | grep -q '"overlap": true' && echo "$OUT_HAPPY" | grep -q '"confidence": 5'; then
  echo "PASS: happy-path verdict parsed"; PASS=$((PASS+1))
else echo "FAIL: happy-path verdict. Got: $OUT_HAPPY"; FAIL=$((FAIL+1)); fi

if echo "$OUT_HAPPY" | grep -q '"judge_status": "ok"'; then
  echo "PASS: judge_status=ok"; PASS=$((PASS+1))
else echo "FAIL: judge_status not ok. Got: $OUT_HAPPY"; FAIL=$((FAIL+1)); fi

# Retry mock: first call returns bad JSON, second call returns good JSON
cat > "$TMP/mock-retry.sh" <<EOF
#!/usr/bin/env bash
COUNTER="$TMP/retry-counter"
N=\$(cat "\$COUNTER" 2>/dev/null || echo 0)
N=\$((N+1))
echo "\$N" > "\$COUNTER"
if [ "\$N" -eq 1 ]; then
  echo "not json at all"
else
  echo '{"overlap": false, "confidence": 3, "rationale": "Retry success."}'
fi
EOF
chmod +x "$TMP/mock-retry.sh"
rm -f "$TMP/retry-counter"

OUT_RETRY=$(JUDGE_CLAUDE_CMD="$TMP/mock-retry.sh" \
            JUDGE_FAILURE_DIR="$TMP/failures" \
            python3 "$SCRIPT" --judge-pair "$TMP/user/sA/SKILL.md" "$TMP/user/sB/SKILL.md" 2>/dev/null)
RC_RETRY=$?

if [ "$RC_RETRY" -eq 0 ]; then echo "PASS: --judge-pair retry exits 0"; PASS=$((PASS+1))
else echo "FAIL: --judge-pair retry exit $RC_RETRY"; FAIL=$((FAIL+1)); fi

if echo "$OUT_RETRY" | grep -q '"overlap": false' && echo "$OUT_RETRY" | grep -q '"judge_status": "ok"'; then
  echo "PASS: retry-once recovers"; PASS=$((PASS+1))
else echo "FAIL: retry-once did not recover. Got: $OUT_RETRY"; FAIL=$((FAIL+1)); fi

# Fail-twice mock: both calls return bad JSON → parse_failed + snapshot written
cat > "$TMP/mock-bad.sh" <<'EOF'
#!/usr/bin/env bash
echo "garbage prose, never json"
EOF
chmod +x "$TMP/mock-bad.sh"

OUT_BAD=$(JUDGE_CLAUDE_CMD="$TMP/mock-bad.sh" \
          JUDGE_FAILURE_DIR="$TMP/failures2" \
          python3 "$SCRIPT" --judge-pair "$TMP/user/sA/SKILL.md" "$TMP/user/sB/SKILL.md" 2>/dev/null)

if echo "$OUT_BAD" | grep -q '"judge_status": "parse_failed"'; then
  echo "PASS: 2nd failure → parse_failed"; PASS=$((PASS+1))
else echo "FAIL: 2nd failure not parse_failed. Got: $OUT_BAD"; FAIL=$((FAIL+1)); fi

if ls "$TMP/failures2"/*.json >/dev/null 2>&1; then
  echo "PASS: failure snapshot written"; PASS=$((PASS+1))
else echo "FAIL: no failure snapshot in $TMP/failures2"; FAIL=$((FAIL+1)); fi

echo "Test 13: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
