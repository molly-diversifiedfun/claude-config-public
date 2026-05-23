#!/usr/bin/env bash
# Test: tier boundaries are correct.
# Uses --tier-from-stdin mode: reads "skillA|skillB|composite" lines, prints
# "skillA|skillB|composite|tier"
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/a" "$TMP/user/b"
echo -e '---\nname: a\ndescription: x\n---' > "$TMP/user/a/SKILL.md"
echo -e '---\nname: b\ndescription: x\n---' > "$TMP/user/b/SKILL.md"

INPUT='a|b|0.149
a|b|0.150
a|b|0.299
a|b|0.300
a|b|0.549
a|b|0.550'

OUT=$(echo "$INPUT" | SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
                      python3 "$SCRIPT" --tier-from-stdin 2>/dev/null)
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

# 0.149 → DROP
if echo "$OUT" | grep -q 'a|b|0.149|DROP'; then echo "PASS: 0.149 → DROP"; PASS=$((PASS+1))
else echo "FAIL: 0.149 → DROP. Got: $OUT"; FAIL=$((FAIL+1)); fi
# 0.150 → LOW
if echo "$OUT" | grep -q 'a|b|0.150|LOW'; then echo "PASS: 0.150 → LOW"; PASS=$((PASS+1))
else echo "FAIL: 0.150 → LOW. Got: $OUT"; FAIL=$((FAIL+1)); fi
# 0.299 → LOW
if echo "$OUT" | grep -q 'a|b|0.299|LOW'; then echo "PASS: 0.299 → LOW"; PASS=$((PASS+1))
else echo "FAIL: 0.299 → LOW. Got: $OUT"; FAIL=$((FAIL+1)); fi
# 0.300 → MEDIUM
if echo "$OUT" | grep -q 'a|b|0.300|MEDIUM'; then echo "PASS: 0.300 → MEDIUM"; PASS=$((PASS+1))
else echo "FAIL: 0.300 → MEDIUM. Got: $OUT"; FAIL=$((FAIL+1)); fi
# 0.549 → MEDIUM
if echo "$OUT" | grep -q 'a|b|0.549|MEDIUM'; then echo "PASS: 0.549 → MEDIUM"; PASS=$((PASS+1))
else echo "FAIL: 0.549 → MEDIUM. Got: $OUT"; FAIL=$((FAIL+1)); fi
# 0.550 → HIGH
if echo "$OUT" | grep -q 'a|b|0.550|HIGH'; then echo "PASS: 0.550 → HIGH"; PASS=$((PASS+1))
else echo "FAIL: 0.550 → HIGH. Got: $OUT"; FAIL=$((FAIL+1)); fi

echo "Test 05: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
