#!/usr/bin/env bash
set -euo pipefail
HOOK="$HOME/.claude/hooks/archetype-injector.sh"

# Sub-dir of ~/github/nancy → should inherit telegram-bot
INPUT='{"cwd":"$HOME/github/nancy/src/handlers","prompt":""}'
CTX=$(echo "$INPUT" | "$HOOK" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -q "Archetype: telegram-bot"; then
  echo "FAIL: prefix match should resolve to telegram-bot. Got: $CTX" >&2
  exit 1
fi
echo "PASS"
