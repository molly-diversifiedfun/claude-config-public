#!/usr/bin/env bash
set +e
SCRIPT="$HOME/.claude/scripts/render-manifest.py"
FIXTURE="$HOME/.claude/test/manifest/fixtures/valid-manifest.yaml"
GOLDEN="$HOME/.claude/test/manifest/fixtures/golden/product-lead.md"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: render-manifest.py not found"; FAIL=$((FAIL+1))
elif [ ! -f "$GOLDEN" ]; then
  echo "FAIL: golden product-lead.md not found (Task 4 must create)"; FAIL=$((FAIL+1))
else
  STDERR_LOG="$TMP/render-stderr.log"
  MANIFEST_PATH="$FIXTURE" python3 "$SCRIPT" --agent product-lead --to "$TMP" >/dev/null 2>"$STDERR_LOG"
  RC=$?
  if [ "$RC" -ne 0 ] || [ ! -f "$TMP/product-lead.md" ]; then
    echo "FAIL: render did not produce product-lead.md (rc=$RC)"
    echo "stderr:"; sed 's/^/  /' "$STDERR_LOG"
    FAIL=$((FAIL+1))
  else
    DIFF=$(diff "$TMP/product-lead.md" "$GOLDEN")
    if [ -z "$DIFF" ]; then
      echo "PASS: product-lead.md matches golden"; PASS=$((PASS+1))
    else
      echo "FAIL: product-lead.md differs from golden:"; echo "$DIFF"; FAIL=$((FAIL+1))
    fi
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
