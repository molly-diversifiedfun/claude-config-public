#!/usr/bin/env bash
# Test: synthetic pair with desc_j=0, body_j≈0.83 surfaces in MEDIUM tier.
# Without Phase 7.7a.1 body signal, this pair would DROP (composite = 0.55 * 0 = 0).
# With Phase 7.7a.1 (jaccard-only rescale): composite = (0.35*0 + 0.20*0.833) / 0.55 ≈ 0.303 → MEDIUM
set +e

SCRIPT="$HOME/.claude/scripts/consolidate-skills.py"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/user/docA" "$TMP/user/docB" "$TMP/reports"

cat > "$TMP/user/docA/SKILL.md" <<'EOF'
---
name: docA
description: kilo lima mike november
---
alpha bravo charlie delta echo foxtrot golf hotel india juliet zulu
EOF

cat > "$TMP/user/docB/SKILL.md" <<'EOF'
---
name: docB
description: oscar papa quebec romeo
---
alpha bravo charlie delta echo foxtrot golf hotel india juliet yankee
EOF

SKILL_CONSOLIDATE_ROOTS="$TMP/user" \
BAKEOFF_LOG_FILE="$TMP/missing.jsonl" \
BAKEOFF_STATS_FILE="$TMP/missing.tsv" \
REPORT_DIR="$TMP/reports" \
python3 "$SCRIPT" >/dev/null 2>&1
RC=$?

REPORT=$(ls "$TMP/reports"/*.md 2>/dev/null | head -1)

if [ "$RC" -eq 0 ]; then echo "PASS: exit 0"; PASS=$((PASS+1))
else echo "FAIL: exit $RC"; FAIL=$((FAIL+1)); fi

if [ -f "$REPORT" ]; then echo "PASS: report created"; PASS=$((PASS+1))
else echo "FAIL: no report"; FAIL=$((FAIL+1)); fi

if grep -qE 'docA.*docB|docB.*docA' "$REPORT"; then
  echo "PASS: cross-vocab pair surfaced (not dropped)"; PASS=$((PASS+1))
else echo "FAIL: pair dropped — body-Jaccard signal not effective"; FAIL=$((FAIL+1)); fi

if awk '/^## MEDIUM/{flag=1; next} /^## /{flag=0} flag && /docA.*docB|docB.*docA/' "$REPORT" | grep -q .; then
  echo "PASS: pair in MEDIUM tier"; PASS=$((PASS+1))
else echo "FAIL: pair not in MEDIUM. Report:"; cat "$REPORT"; FAIL=$((FAIL+1)); fi

echo "Test 10: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
