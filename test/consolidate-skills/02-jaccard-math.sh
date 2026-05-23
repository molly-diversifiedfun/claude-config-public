#!/usr/bin/env bash
# Test: Jaccard math correct on known token sets.
# Uses --jaccard-only mode: prints "skillA | skillB | jaccard_norm" per pair.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Identical descriptions → Jaccard = 1.0
mkdir -p "$TMP/user/foo" "$TMP/user/bar" "$TMP/user/baz"
echo -e '---\nname: foo\ndescription: write blog post fast\n---' > "$TMP/user/foo/SKILL.md"
echo -e '---\nname: bar\ndescription: write blog post fast\n---' > "$TMP/user/bar/SKILL.md"
# Disjoint description → Jaccard = 0.0
echo -e '---\nname: baz\ndescription: deploy kubernetes cluster\n---' > "$TMP/user/baz/SKILL.md"

OUT=$(SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
      python3 "$SCRIPT" --jaccard-only 2>/dev/null)
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

# bar↔foo: identical descriptions → 1.000 (alphabetical pair order)
if echo "$OUT" | grep -E 'bar \| foo \| 1\.0+' > /dev/null; then echo "PASS: bar↔foo = 1.0"; PASS=$((PASS+1))
else echo "FAIL: bar↔foo Jaccard. Got: $OUT"; FAIL=$((FAIL+1)); fi

# bar↔baz: disjoint → 0.000
if echo "$OUT" | grep -E 'bar \| baz \| 0\.0+' > /dev/null; then echo "PASS: bar↔baz = 0.0"; PASS=$((PASS+1))
else echo "FAIL: bar↔baz Jaccard. Got: $OUT"; FAIL=$((FAIL+1)); fi

echo "Test 02: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
