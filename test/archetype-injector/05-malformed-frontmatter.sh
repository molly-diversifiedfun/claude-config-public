#!/usr/bin/env bash
# Inject a malformed file temporarily; verify hook doesn't crash and falls open.
set -euo pipefail
HOOK="$HOME/.claude/hooks/archetype-injector.sh"
LEARNED="$HOME/.claude/skills/learned"
TMP_PATTERN="$LEARNED/zz-test-malformed.md"

cleanup() { rm -f "$TMP_PATTERN"; }
trap cleanup EXIT

cat > "$TMP_PATTERN" <<'EOF'
---
name: zz-test-malformed
this is not valid frontmatter
EOF

INPUT='{"cwd":"$HOME/github/<your-bot>","prompt":""}'
OUT=$(echo "$INPUT" | "$HOOK")
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook crashed on malformed file (rc=$RC). Got: $OUT" >&2
  exit 1
fi

# Best-effort: malformed file should not break overall output.
if ! echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  echo "FAIL: hook returned no additionalContext on malformed file: $OUT" >&2
  exit 1
fi

echo "PASS"
