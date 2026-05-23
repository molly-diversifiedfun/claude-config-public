#!/usr/bin/env bash
# Test: extract_body() strips frontmatter + fenced code blocks; prose + bullets remain.
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/example"
cat > "$TMP/user/example/SKILL.md" <<'EOF'
---
name: example
description: testing body extraction
---
PROSE_SENTINEL_VISIBLE this paragraph stays in the extracted body.

```python
def secret():
    return "PYTHON_SECRET_HIDDEN should not appear"
```

More prose between code blocks.

```bash
echo "BASH_SECRET_HIDDEN should not appear"
```

- BULLET_SENTINEL_VISIBLE bullet item one
- BULLET_SENTINEL_TWO bullet item two
EOF

OUT=$(python3 "$SCRIPT" --extract-body "$TMP/user/example/SKILL.md" 2>/dev/null)
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if echo "$OUT" | grep -q 'PROSE_SENTINEL_VISIBLE'; then echo "PASS: prose retained"; PASS=$((PASS+1))
else echo "FAIL: prose missing"; FAIL=$((FAIL+1)); fi

if echo "$OUT" | grep -q 'BULLET_SENTINEL_VISIBLE'; then echo "PASS: bullet retained"; PASS=$((PASS+1))
else echo "FAIL: bullet missing"; FAIL=$((FAIL+1)); fi

if echo "$OUT" | grep -q 'PYTHON_SECRET_HIDDEN'; then
  echo "FAIL: python code leaked"; FAIL=$((FAIL+1))
else echo "PASS: python code stripped"; PASS=$((PASS+1)); fi

if echo "$OUT" | grep -q 'BASH_SECRET_HIDDEN'; then
  echo "FAIL: bash code leaked"; FAIL=$((FAIL+1))
else echo "PASS: bash code stripped"; PASS=$((PASS+1)); fi

if echo "$OUT" | grep -qE '^---$'; then
  echo "FAIL: frontmatter delimiter leaked"; FAIL=$((FAIL+1))
else echo "PASS: frontmatter stripped"; PASS=$((PASS+1)); fi

echo "Test 09: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
