#!/usr/bin/env bash
set +e
SCRIPT="$HOME/.claude/scripts/validate-manifest.sh"
FIXTURE="$HOME/.claude/test/manifest/fixtures/valid-manifest.yaml"
PASS=0; FAIL=0

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: validate-manifest.sh not found"; FAIL=$((FAIL+1))
else
  OUT=$(MANIFEST_PATH="$FIXTURE" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "13/13 OK"; then
    echo "PASS: valid manifest passes"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 0 + 13/13 OK (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
