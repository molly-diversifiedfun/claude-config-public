#!/usr/bin/env bash
# Test: mocked Sonnet returns a valid merged SKILL.md; script writes draft, prints diffs + instructions.
set +e

SCRIPT="$HOME/.claude/scripts/merge-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Two source skills
mkdir -p "$TMP/skills/alpha" "$TMP/skills/beta"
cat > "$TMP/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: alpha skill desc
triggers: [foo, bar]
allowed-tools: [Read, Write]
---
# Alpha

Alpha body content.
EOF
cat > "$TMP/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: beta skill desc
triggers: [baz]
allowed-tools: [Read, Edit]
---
# Beta

Beta body content.
EOF

# Mock claude binary
cat > "$TMP/mock-claude.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'MERGED'
---
name: alphabeta
description: merged alpha and beta synthesis
triggers: [foo, bar, baz]
allowed-tools: [Read, Write, Edit]
---
# AlphaBeta

Merged body content from both alpha and beta.
MERGED
EOF
chmod +x "$TMP/mock-claude.sh"

export MERGE_CLAUDE_CMD="$TMP/mock-claude.sh"
export MERGE_DRAFTS_ROOT="$TMP/_drafts"

OUT=$(python3 "$SCRIPT" "$TMP/skills/alpha/SKILL.md" "$TMP/skills/beta/SKILL.md" 2>"$TMP/stderr")
RC=$?

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if [ -f "$TMP/_drafts/alphabeta/SKILL.md" ]; then echo "PASS: draft file written"; PASS=$((PASS+1))
else echo "FAIL: draft file missing"; FAIL=$((FAIL+1)); fi

if grep -q "merged alpha and beta synthesis" "$TMP/_drafts/alphabeta/SKILL.md" 2>/dev/null; then
  echo "PASS: draft content matches mock"; PASS=$((PASS+1))
else echo "FAIL: draft content mismatch"; FAIL=$((FAIL+1)); fi

if grep -q "diff vs Skill A" "$TMP/stderr"; then echo "PASS: stderr has Skill A diff header"; PASS=$((PASS+1))
else echo "FAIL: missing Skill A diff header"; FAIL=$((FAIL+1)); fi

if grep -q "diff vs Skill B" "$TMP/stderr"; then echo "PASS: stderr has Skill B diff header"; PASS=$((PASS+1))
else echo "FAIL: missing Skill B diff header"; FAIL=$((FAIL+1)); fi

if echo "$OUT" | grep -q "To accept:"; then echo "PASS: stdout has acceptance instructions"; PASS=$((PASS+1))
else echo "FAIL: missing acceptance instructions"; FAIL=$((FAIL+1)); fi

echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
