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
  # Place a fake slash command file in a TMP commands dir not referenced by manifest.
  # Use COMMANDS_OVERRIDE env var (Task 3 must support it).
  mkdir -p "$TMP/commands"
  cat > "$TMP/commands/orphan-command.md" <<'CMDEOF'
# /orphan-command
A slash command not declared in any agent's owns_slash_commands.
CMDEOF
  OUT=$(MANIFEST_PATH="$FIXTURE" COMMANDS_OVERRIDE="$TMP/commands" "$SCRIPT" 2>&1)
  RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "unowned slash command"; then
    echo "PASS: orphan slash command rejected"; PASS=$((PASS+1))
  else
    echo "FAIL: expected exit 1 + 'unowned slash command' (rc=$RC, out=$OUT)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
