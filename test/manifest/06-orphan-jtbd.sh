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
  # Add a JTBD entry with no owner field
  FIXTURE="$FIXTURE" OUT_PATH="$TMP/manifest.yaml" python3 <<'PYEOF'
import os
src = open(os.environ['FIXTURE']).read()
orphan = """
  - id: floating-jtbd
    role: builder
    description: An orphan JTBD with no owner
    specialists: []
    skills: []
"""
marker = "    skills: [brand-voice-router, carousel-writer]\n"
out = src.replace(marker, marker + orphan, 1)
open(os.environ['OUT_PATH'], 'w').write(out)
PYEOF
  OUT=$(MANIFEST_PATH="$TMP/manifest.yaml" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "JTBD orphan"; then
    echo "PASS: orphan jtbd rejected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'JTBD orphan' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
