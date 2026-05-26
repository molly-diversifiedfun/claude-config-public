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
  # Mutate builder's kind: pipeline_owner -> kind: foo (first occurrence)
  FIXTURE="$FIXTURE" OUT_PATH="$TMP/manifest.yaml" python3 <<'PYEOF'
import os
src = open(os.environ['FIXTURE']).read()
out = src.replace('kind: pipeline_owner', 'kind: foo', 1)
open(os.environ['OUT_PATH'], 'w').write(out)
PYEOF
  OUT=$(MANIFEST_PATH="$TMP/manifest.yaml" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "unknown kind: foo"; then
    echo "PASS: unknown kind rejected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'unknown kind: foo' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
