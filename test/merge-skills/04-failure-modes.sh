#!/usr/bin/env bash
# Test: 5 sub-tests for failure modes — missing path, kill switch, non-zero exit, empty output, no frontmatter.
set +e

SCRIPT="$HOME/.claude/scripts/merge-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/skills/aaa" "$TMP/skills/bbb"
cat > "$TMP/skills/aaa/SKILL.md" <<'EOF'
---
name: aaa
---
body aaa
EOF
cat > "$TMP/skills/bbb/SKILL.md" <<'EOF'
---
name: bbb
---
body bbb
EOF

# (a) missing path
python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/nonexistent.md" >/dev/null 2>"$TMP/stderr-a"
RC=$?
if [ "$RC" -eq 2 ] && grep -q "not a file" "$TMP/stderr-a"; then
  echo "PASS: missing path → exit 2 + 'not a file' on stderr"; PASS=$((PASS+1))
else echo "FAIL: expected exit 2 + 'not a file' on stderr (rc=$RC, stderr=$(cat $TMP/stderr-a 2>/dev/null))"; FAIL=$((FAIL+1)); fi

# (b) MERGE_SKILLS=off kill switch
OUT=$(MERGE_SKILLS=off python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "disabled"; then
  echo "PASS: MERGE_SKILLS=off → exit 0 + disabled message"; PASS=$((PASS+1))
else echo "FAIL: kill switch didn't fire (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1)); fi

# (c) mock exits non-zero
cat > "$TMP/mock-fail.sh" <<'EOF'
#!/usr/bin/env bash
echo "boom" >&2
exit 3
EOF
chmod +x "$TMP/mock-fail.sh"
MERGE_CLAUDE_CMD="$TMP/mock-fail.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>"$TMP/stderr-c"
RC=$?
if [ "$RC" -eq 1 ] && grep -q "synthesis failed" "$TMP/stderr-c"; then
  echo "PASS: mock non-zero → exit 1 + 'synthesis failed'"; PASS=$((PASS+1))
else echo "FAIL: expected exit 1 + 'synthesis failed' (rc=$RC)"; FAIL=$((FAIL+1)); fi

# (d) mock returns empty
cat > "$TMP/mock-empty.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/mock-empty.sh"
rm -rf "$TMP/_drafts"
MERGE_CLAUDE_CMD="$TMP/mock-empty.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>"$TMP/stderr-d"
RC=$?
if [ "$RC" -eq 1 ] && grep -q "empty output" "$TMP/stderr-d"; then
  echo "PASS: empty output → exit 1 + 'empty output'"; PASS=$((PASS+1))
else echo "FAIL: expected exit 1 + 'empty output' (rc=$RC)"; FAIL=$((FAIL+1)); fi

# (e) mock returns garbage (no frontmatter) → still writes draft with fallback name
cat > "$TMP/mock-garbage.sh" <<'EOF'
#!/usr/bin/env bash
echo "just some prose with no frontmatter at all"
EOF
chmod +x "$TMP/mock-garbage.sh"
rm -rf "$TMP/_drafts"
MERGE_CLAUDE_CMD="$TMP/mock-garbage.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>&1
RC=$?
if [ "$RC" -eq 0 ] && [ -f "$TMP/_drafts/merged-aaa-bbb/SKILL.md" ]; then
  echo "PASS: garbage output → exit 0 + fallback draft written"; PASS=$((PASS+1))
else echo "FAIL: expected exit 0 + _drafts/merged-aaa-bbb/SKILL.md (rc=$RC)"; FAIL=$((FAIL+1)); fi

echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
