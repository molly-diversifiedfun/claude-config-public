#!/usr/bin/env bash
[ "$SKILL_DIR_BASELINE_CHECK" = "on" ] || { echo "SKIP: gated by SKILL_DIR_BASELINE_CHECK"; exit 0; }
set +e
SCRIPT="$HOME/.claude/scripts/render-manifest.py"
FIXTURE="$HOME/.claude/test/manifest/fixtures/valid-manifest.yaml"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: render-manifest.py not found"; FAIL=$((FAIL+1))
else
  # Phase B: validate that every skill referenced by every agent exists in ~/.claude/skills
  # Placeholder for now — once enabled, list manifest skills + check against directory.
  echo "FAIL: Phase B skill-directory baseline not implemented"; FAIL=$((FAIL+1))
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
