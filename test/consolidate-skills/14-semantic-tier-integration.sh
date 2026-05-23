#!/usr/bin/env bash
# Test: ambiguity-band pair + mocked judge → SEMANTIC tier at top of report.
# Also tests --no-judge flag suppresses the layer entirely.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/sA" "$TMP/user/sB" "$TMP/reports"

# Body tokens chosen to produce composite in [0.15, 0.30) ambiguity band:
# - desc disjoint (Jaccard=0)
# - body shares 7 of 11 unique → Jaccard ≈ 0.636
# - Jaccard-only composite = (0.20 * 0.636) / 0.55 ≈ 0.231 → in band

cat > "$TMP/user/sA/SKILL.md" <<'EOF'
---
name: sA
description: kilo lima mike november
---
alphax bravox charliex deltax echox foxtrotx golfx uniqaone uniqatwo
EOF
cat > "$TMP/user/sB/SKILL.md" <<'EOF'
---
name: sB
description: oscar papa quebec romeo
---
alphax bravox charliex deltax echox foxtrotx golfx uniqbone uniqbtwo
EOF

# Mock judge: returns high-confidence overlap
cat > "$TMP/mock-judge.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"overlap": true, "confidence": 5, "rationale": "Mocked semantic match."}'
EOF
chmod +x "$TMP/mock-judge.sh"

SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
BAKEOFF_LOG_FILE="$TMP/missing.jsonl" \
BAKEOFF_STATS_FILE="$TMP/missing.tsv" \
REPORT_DIR="$TMP/reports" \
JUDGE_CACHE_FILE="$TMP/cache.jsonl" \
JUDGE_CLAUDE_CMD="$TMP/mock-judge.sh" \
JUDGE_FAILURE_DIR="$TMP/failures" \
python3 "$SCRIPT" >/dev/null 2>&1
RC=$?

REPORT=$(ls "$TMP/reports"/*.md 2>/dev/null | head -1)

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if [ -f "$REPORT" ]; then echo "PASS: report created"; PASS=$((PASS+1))
else echo "FAIL: no report"; FAIL=$((FAIL+1)); fi

# SEMANTIC tier present
if grep -q '^## SEMANTIC' "$REPORT"; then echo "PASS: SEMANTIC section present"; PASS=$((PASS+1))
else echo "FAIL: no SEMANTIC section. Report:"; cat "$REPORT"; FAIL=$((FAIL+1)); fi

# SEMANTIC comes BEFORE HIGH in the file (top of report)
SEM_LINE=$(grep -n '^## SEMANTIC' "$REPORT" | head -1 | cut -d: -f1)
HIGH_LINE=$(grep -n '^## HIGH' "$REPORT" | head -1 | cut -d: -f1)
if [ -n "$SEM_LINE" ] && [ -n "$HIGH_LINE" ] && [ "$SEM_LINE" -lt "$HIGH_LINE" ]; then
  echo "PASS: SEMANTIC appears before HIGH"; PASS=$((PASS+1))
else echo "FAIL: SEMANTIC line=$SEM_LINE HIGH line=$HIGH_LINE"; FAIL=$((FAIL+1)); fi

# Pair appears in SEMANTIC section
if awk '/^## SEMANTIC/{flag=1; next} /^## /{flag=0} flag && /sA.*sB|sB.*sA/' "$REPORT" | grep -q .; then
  echo "PASS: pair in SEMANTIC tier"; PASS=$((PASS+1))
else echo "FAIL: pair not in SEMANTIC. Report:"; cat "$REPORT"; FAIL=$((FAIL+1)); fi

# Judge footer line present
if grep -q '^\*\*Judge:\*\*.*judged=' "$REPORT"; then echo "PASS: judge footer line"; PASS=$((PASS+1))
else echo "FAIL: no judge footer. Report tail:"; tail -10 "$REPORT"; FAIL=$((FAIL+1)); fi

# Cache populated
if [ -s "$TMP/cache.jsonl" ]; then echo "PASS: cache written"; PASS=$((PASS+1))
else echo "FAIL: cache empty"; FAIL=$((FAIL+1)); fi

# --no-judge flag suppresses SEMANTIC
rm -f "$TMP/reports"/*.md
SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
BAKEOFF_LOG_FILE="$TMP/missing.jsonl" \
BAKEOFF_STATS_FILE="$TMP/missing.tsv" \
REPORT_DIR="$TMP/reports" \
JUDGE_CACHE_FILE="$TMP/cache2.jsonl" \
JUDGE_CLAUDE_CMD="$TMP/mock-judge.sh" \
JUDGE_FAILURE_DIR="$TMP/failures2" \
python3 "$SCRIPT" --no-judge >/dev/null 2>&1

REPORT2=$(ls "$TMP/reports"/*.md 2>/dev/null | head -1)

if [ -f "$REPORT2" ] && ! grep -q '^## SEMANTIC' "$REPORT2"; then
  echo "PASS: --no-judge suppresses SEMANTIC"; PASS=$((PASS+1))
else echo "FAIL: --no-judge did not suppress SEMANTIC"; FAIL=$((FAIL+1)); fi

if [ -f "$REPORT2" ] && ! grep -q '^\*\*Judge:\*\*' "$REPORT2"; then
  echo "PASS: --no-judge suppresses judge footer"; PASS=$((PASS+1))
else echo "FAIL: --no-judge did not suppress judge footer"; FAIL=$((FAIL+1)); fi

echo "Test 14: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
