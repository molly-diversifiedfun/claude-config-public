#!/usr/bin/env bash
# Test: (a) mock returns frontmatter `name: foo-bar` → draft at _drafts/foo-bar/. (b) no name → fallback merged-<a>-<b>.
set +e

SCRIPT="$HOME/.claude/scripts/merge-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/skills/aaa" "$TMP/skills/bbb"
cat > "$TMP/skills/aaa/SKILL.md" <<'EOF'
---
name: aaa
description: aaa
---
body aaa
EOF
cat > "$TMP/skills/bbb/SKILL.md" <<'EOF'
---
name: bbb
description: bbb
---
body bbb
EOF

# Sub-test (a): valid frontmatter name
cat > "$TMP/mock-with-name.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'MERGED'
---
name: foo-bar
description: synthesized desc
---
synth body
MERGED
EOF
chmod +x "$TMP/mock-with-name.sh"

MERGE_CLAUDE_CMD="$TMP/mock-with-name.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>&1
RC=$?

if [ "$RC" -eq 0 ] && [ -f "$TMP/_drafts/foo-bar/SKILL.md" ]; then
  echo "PASS: extracted name 'foo-bar' used as draft dir"; PASS=$((PASS+1))
else echo "FAIL: draft not at _drafts/foo-bar/ (rc=$RC)"; FAIL=$((FAIL+1)); fi

# Sub-test (b): no frontmatter name → fallback
rm -rf "$TMP/_drafts"
cat > "$TMP/mock-no-name.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'MERGED'
This output has no frontmatter at all.
Just prose body.
MERGED
EOF
chmod +x "$TMP/mock-no-name.sh"

MERGE_CLAUDE_CMD="$TMP/mock-no-name.sh" MERGE_DRAFTS_ROOT="$TMP/_drafts" \
  python3 "$SCRIPT" "$TMP/skills/aaa/SKILL.md" "$TMP/skills/bbb/SKILL.md" >/dev/null 2>&1
RC=$?

if [ "$RC" -eq 0 ] && [ -f "$TMP/_drafts/merged-aaa-bbb/SKILL.md" ]; then
  echo "PASS: fallback name 'merged-aaa-bbb' used"; PASS=$((PASS+1))
else echo "FAIL: fallback draft not at _drafts/merged-aaa-bbb/ (rc=$RC)"; FAIL=$((FAIL+1)); fi

echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
