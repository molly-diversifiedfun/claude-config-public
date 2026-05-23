#!/usr/bin/env bash
# Test: shared bake-off losses counted correctly from fixture JSONL.
# --score-only mode prints "skillA | skillB | desc_jaccard | body_jaccard | losses | elim | composite-placeholder"
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/x" "$TMP/user/y" "$TMP/user/z" "$TMP/data"
echo -e '---\nname: x\ndescription: alpha beta\n---' > "$TMP/user/x/SKILL.md"
echo -e '---\nname: y\ndescription: gamma delta\n---' > "$TMP/user/y/SKILL.md"
echo -e '---\nname: z\ndescription: epsilon zeta\n---' > "$TMP/user/z/SKILL.md"

# Schema per scripts/bake-off-record.sh: { "run_id":"r1", "winner":"a", "losers":["x","y"] }
cat > "$TMP/data/log.jsonl" <<'EOF'
{"run_id":"r1","winner":"a","losers":["x","y"]}
{"run_id":"r2","winner":"b","losers":["x","y"]}
{"run_id":"r3","winner":"c","losers":["x","z"]}
EOF

OUT=$(SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
      BAKEOFF_LOG_FILE="$TMP/data/log.jsonl" \
      BAKEOFF_STATS_FILE="$TMP/data/nonexistent.tsv" \
      python3 "$SCRIPT" --score-only 2>/dev/null)
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

# x↔y co-lost in r1 and r2 → shared_losses = 2
if echo "$OUT" | awk -F' \\| ' '$1=="x" && $2=="y" {print $5}' | grep -E '^2$' > /dev/null; then
  echo "PASS: x↔y shared_losses = 2"; PASS=$((PASS+1))
else echo "FAIL: x↔y shared_losses. Got: $OUT"; FAIL=$((FAIL+1)); fi

# x↔z co-lost only in r3 → shared_losses = 1
if echo "$OUT" | awk -F' \\| ' '$1=="x" && $2=="z" {print $5}' | grep -E '^1$' > /dev/null; then
  echo "PASS: x↔z shared_losses = 1"; PASS=$((PASS+1))
else echo "FAIL: x↔z shared_losses. Got: $OUT"; FAIL=$((FAIL+1)); fi

# y↔z never co-lost → shared_losses = 0
if echo "$OUT" | awk -F' \\| ' '$1=="y" && $2=="z" {print $5}' | grep -E '^0$' > /dev/null; then
  echo "PASS: y↔z shared_losses = 0"; PASS=$((PASS+1))
else echo "FAIL: y↔z shared_losses. Got: $OUT"; FAIL=$((FAIL+1)); fi

echo "Test 03: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
