#!/usr/bin/env bash
# Test: elim_norm = 1.0 if either skill in pair has ≥3 appearances + 0 wins.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/p" "$TMP/user/q" "$TMP/data"
echo -e '---\nname: p\ndescription: alpha\n---' > "$TMP/user/p/SKILL.md"
echo -e '---\nname: q\ndescription: beta\n---' > "$TMP/user/q/SKILL.md"

# TSV schema per scripts/bake-off-record.sh: skill\tappearances\twins\tlosses\tlast_run_iso
printf 'skill\tappearances\twins\tlosses\tlast_run_iso\n' > "$TMP/data/stats.tsv"
printf 'p\t5\t0\t5\t2026-05-20T00:00:00Z\n' >> "$TMP/data/stats.tsv"  # eliminated
printf 'q\t10\t8\t2\t2026-05-20T00:00:00Z\n' >> "$TMP/data/stats.tsv"  # not eliminated

OUT=$(SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
      BAKEOFF_LOG_FILE="$TMP/data/nonexistent.jsonl" \
      BAKEOFF_STATS_FILE="$TMP/data/stats.tsv" \
      python3 "$SCRIPT" --score-only 2>/dev/null)
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

# p↔q: p eliminated → elim column = 1
if echo "$OUT" | awk -F' \\| ' '$1=="p" && $2=="q" {print $6}' | grep -E '^1$' > /dev/null; then
  echo "PASS: p↔q elim = 1"; PASS=$((PASS+1))
else echo "FAIL: p↔q elim. Got: $OUT"; FAIL=$((FAIL+1)); fi

echo "Test 04: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
