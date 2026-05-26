#!/usr/bin/env bash
set +e
SCRIPT="$HOME/.claude/scripts/validate-manifest.sh"
FIXTURE="$HOME/.claude/test/manifest/fixtures/valid-manifest.yaml"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: validate-manifest.sh not found"; FAIL=$((FAIL+1))
else
  # Change ship-a-feature.owner from builder to content-qa (a utility_specialist)
  FIXTURE="$FIXTURE" OUT_PATH="$TMP/manifest.yaml" python3 <<'PYEOF'
import os
src = open(os.environ['FIXTURE']).read()
old = """  - id: ship-a-feature
    role: builder
    description: Implement a feature with tests, review, deploy
    owner: builder"""
new = """  - id: ship-a-feature
    role: builder
    description: Implement a feature with tests, review, deploy
    owner: content-qa"""
open(os.environ['OUT_PATH'], 'w').write(src.replace(old, new))
PYEOF
  OUT=$(MANIFEST_PATH="$TMP/manifest.yaml" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "owner must be pipeline_owner"; then
    echo "PASS: specialist as JTBD owner rejected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'owner must be pipeline_owner' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
