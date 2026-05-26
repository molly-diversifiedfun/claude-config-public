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
  # Create TMP agent.md WITH header but altered body (hash won't match manifest expectation)
  mkdir -p "$TMP/agents"
  cat > "$TMP/agents/builder.md" <<'AGENTEOF'
<!-- DO NOT EDIT - generated from agent-skill-manifest.yaml -->
---
name: builder
kind: pipeline_owner
model: sonnet
description: Owns /plan, /build, /ship, /fix
---

# builder

THIS BODY HAS BEEN TAMPERED WITH — diverges from manifest output.
AGENTEOF
  OUT=$(MANIFEST_PATH="$FIXTURE" AGENTS_OUT_DIR="$TMP/agents" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "drift detected"; then
    echo "PASS: hash mismatch detected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'drift detected' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
