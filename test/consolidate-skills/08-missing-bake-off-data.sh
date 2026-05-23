#!/usr/bin/env bash
# Test: missing bake-off files → Jaccard-only fallback + footer warning.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/m" "$TMP/user/n" "$TMP/reports"
echo -e '---\nname: m\ndescription: humanize ai writing voice\n---' > "$TMP/user/m/SKILL.md"
echo -e '---\nname: n\ndescription: humanize ai writing voice\n---' > "$TMP/user/n/SKILL.md"

# Both bake-off files missing
SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
BAKEOFF_LOG_FILE="$TMP/missing.jsonl" \
BAKEOFF_STATS_FILE="$TMP/missing.tsv" \
REPORT_DIR="$TMP/reports" \
python3 "$SCRIPT" >/dev/null 2>&1
RC=$?

REPORT=$(ls "$TMP/reports"/*.md 2>/dev/null | head -1)

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if [ -f "$REPORT" ]; then echo "PASS: report created"; PASS=$((PASS+1))
else echo "FAIL: no report"; FAIL=$((FAIL+1)); fi

# Footer warning for Jaccard-only mode
if grep -qi 'jaccard-only mode\|bake-off.*unavailable' "$REPORT"; then
  echo "PASS: fallback warning in footer"; PASS=$((PASS+1))
else echo "FAIL: no fallback warning in $REPORT"; FAIL=$((FAIL+1)); fi

# m↔n still flagged HIGH (identical descriptions, Jaccard=1.0 → composite = 1.0 in fallback)
if grep -q '^## HIGH' "$REPORT"; then echo "PASS: HIGH section present in fallback"; PASS=$((PASS+1))
else echo "FAIL: HIGH section missing"; FAIL=$((FAIL+1)); fi

echo "Test 08: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
