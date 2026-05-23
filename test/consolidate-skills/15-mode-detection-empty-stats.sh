#!/usr/bin/env bash
# Test: empty bake-off-stats.tsv (header-only or zero-row) triggers jaccard-only mode,
# same as a missing file. Verifies the Phase 7.7a.3 mode-detection fix.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/m" "$TMP/user/n" "$TMP/reports"
echo -e '---\nname: m\ndescription: humanize ai writing voice\n---' > "$TMP/user/m/SKILL.md"
echo -e '---\nname: n\ndescription: humanize ai writing voice\n---' > "$TMP/user/n/SKILL.md"

# Empty stats file (header only, zero data rows)
printf 'skill\tappearances\twins\tlosses\tlast_run_iso\n' > "$TMP/empty-stats.tsv"
# Missing bake-off log
touch "$TMP/empty-log.jsonl"

SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
BAKEOFF_LOG_FILE="$TMP/empty-log.jsonl" \
BAKEOFF_STATS_FILE="$TMP/empty-stats.tsv" \
REPORT_DIR="$TMP/reports" \
python3 "$SCRIPT" --no-judge >/dev/null 2>&1
RC=$?

REPORT=$(ls "$TMP/reports"/*.md 2>/dev/null | head -1)

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if [ -f "$REPORT" ]; then echo "PASS: report created"; PASS=$((PASS+1))
else echo "FAIL: no report"; FAIL=$((FAIL+1)); fi

# Empty stats + empty log → jaccard-only mode → composite-rescale applied →
# m↔n (identical descriptions, Jaccard=1.0) → composite=1.0 → HIGH tier
if grep -q '^## HIGH' "$REPORT"; then echo "PASS: HIGH section present"; PASS=$((PASS+1))
else echo "FAIL: no HIGH section (mode-detection bug — empty stats should trigger jaccard-only)"; FAIL=$((FAIL+1)); fi

# Jaccard-only banner present (proves mode-detection works correctly with empty stats file)
if grep -qi 'jaccard-only mode\|bake-off.*unavailable' "$REPORT"; then
  echo "PASS: jaccard-only mode banner present"; PASS=$((PASS+1))
else echo "FAIL: no jaccard-only banner — full mode fired incorrectly on empty stats"; FAIL=$((FAIL+1)); fi

# m↔n pair must be in HIGH (composite 1.0 in jaccard-only rescale: (0.35*1 + 0.20*1)/0.55 = 1.0)
if awk '/^## HIGH/{flag=1; next} /^## /{flag=0} flag && /m.*n|n.*m/' "$REPORT" | grep -q .; then
  echo "PASS: m↔n pair in HIGH tier"; PASS=$((PASS+1))
else echo "FAIL: m↔n pair not in HIGH. Report:"; cat "$REPORT"; FAIL=$((FAIL+1)); fi

echo "Test 15: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
