#!/usr/bin/env bash
set +e
SCRIPT="$HOME/.claude/scripts/validate-manifest.sh"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: validate-manifest.sh not found"; FAIL=$((FAIL+1))
else
  # Write a manifest with empty agents block
  cat > "$TMP/manifest.yaml" <<'YAMLEOF'
version: 1
last_updated: 2026-05-24

roles: []
jtbd: []
agents: {}
YAMLEOF
  OUT=$(MANIFEST_PATH="$TMP/manifest.yaml" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "no agents defined"; then
    echo "PASS: empty manifest rejected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'no agents defined' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
