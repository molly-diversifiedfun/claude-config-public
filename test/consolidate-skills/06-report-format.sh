#!/usr/bin/env bash
# Test: full report has HIGH/MEDIUM/LOW sections + audit-trail footer.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/voice1" "$TMP/user/voice2" "$TMP/user/unrelated" "$TMP/reports"
echo -e '---\nname: voice1\ndescription: humanize ai writing voice patterns\n---' > "$TMP/user/voice1/SKILL.md"
echo -e '---\nname: voice2\ndescription: humanize ai writing voice patterns\n---' > "$TMP/user/voice2/SKILL.md"
echo -e '---\nname: unrelated\ndescription: deploy kubernetes containerized workloads\n---' > "$TMP/user/unrelated/SKILL.md"

SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
BAKEOFF_LOG_FILE="$TMP/nonexistent.jsonl" \
BAKEOFF_STATS_FILE="$TMP/nonexistent.tsv" \
REPORT_DIR="$TMP/reports" \
python3 "$SCRIPT" --no-judge >/dev/null 2>&1
RC=$?

REPORT=$(ls "$TMP/reports"/*.md 2>/dev/null | head -1)

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if [ -f "$REPORT" ]; then echo "PASS: report file created"; PASS=$((PASS+1))
else echo "FAIL: no report file in $TMP/reports"; FAIL=$((FAIL+1)); fi

# HIGH section present (voice1↔voice2 identical → composite ≥ 0.55 even in Jaccard-only)
if grep -q '^## HIGH' "$REPORT"; then echo "PASS: HIGH section"; PASS=$((PASS+1))
else echo "FAIL: no HIGH section in $REPORT"; FAIL=$((FAIL+1)); fi

# Footer with signal availability
if grep -q '^\*\*Signal availability\*\*' "$REPORT"; then echo "PASS: footer signal availability"; PASS=$((PASS+1))
else echo "FAIL: no footer"; FAIL=$((FAIL+1)); fi

# Footer with source weights
if grep -q 'desc=0.35' "$REPORT"; then echo "PASS: weights cited"; PASS=$((PASS+1))
else echo "FAIL: weights not in footer"; FAIL=$((FAIL+1)); fi

echo "Test 06: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
