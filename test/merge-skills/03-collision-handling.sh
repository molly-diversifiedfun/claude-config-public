#!/usr/bin/env bash
# Test: (a) production-skill name collision → suffix `-merged`. (b) draft dir already exists → exit 1.
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

cat > "$TMP/mock-claude.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'MERGED'
---
name: existing-skill
description: clash
---
body
MERGED
EOF
chmod +x "$TMP/mock-claude.sh"

# Sub-test (a): pre-create skills/existing-skill so production-name collides
mkdir -p "$TMP/skills_root/existing-skill"
MERGE_CLAUDE_CMD="$TMP/mock-claude.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  MERGE_SKILLS_ROOT="$TMP/skills_root" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>&1
RC=$?

if [ "$RC" -eq 0 ] && [ -f "$TMP/_drafts/existing-skill-merged/SKILL.md" ]; then
  echo "PASS: production collision → suffix '-merged' applied"; PASS=$((PASS+1))
else echo "FAIL: expected _drafts/existing-skill-merged/SKILL.md (rc=$RC)"; FAIL=$((FAIL+1)); fi

# Sub-test (b): pre-create draft dir
rm -rf "$TMP/_drafts" "$TMP/skills_root"
mkdir -p "$TMP/_drafts/existing-skill"
MERGE_CLAUDE_CMD="$TMP/mock-claude.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>"$TMP/stderr-3b"
RC=$?

if [ "$RC" -eq 1 ] && grep -q "draft already exists" "$TMP/stderr-3b"; then
  echo "PASS: existing draft → exit 1 + 'draft already exists' on stderr"; PASS=$((PASS+1))
else echo "FAIL: expected exit 1 + 'draft already exists' on stderr (rc=$RC, stderr=$(cat $TMP/stderr-3b 2>/dev/null))"; FAIL=$((FAIL+1)); fi

echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
