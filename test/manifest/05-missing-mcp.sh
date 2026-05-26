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
  # Add a nonexistent mcp server to builder.tools.mcp
  FIXTURE="$FIXTURE" OUT_PATH="$TMP/manifest.yaml" python3 <<'PYEOF'
import os
src = open(os.environ['FIXTURE']).read()
old = "      built_in: [Read, Write, Edit, Bash, AskUserQuestion, Task]\n      mcp: [mempalace]"
new = "      built_in: [Read, Write, Edit, Bash, AskUserQuestion, Task]\n      mcp: [mempalace, nonexistent-mcp-xyz]"
open(os.environ['OUT_PATH'], 'w').write(src.replace(old, new, 1))
PYEOF
  OUT=$(MANIFEST_PATH="$TMP/manifest.yaml" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "mcp server not enabled"; then
    echo "PASS: missing mcp rejected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'mcp server not enabled' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
