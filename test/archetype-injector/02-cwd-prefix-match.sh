#!/usr/bin/env bash
set -euo pipefail
HOOK="$HOME/.claude/hooks/archetype-injector.sh"

# Sub-dir of ~/github/<your-bot> → should inherit telegram-bot
INPUT='{"cwd":"$HOME/github/<your-bot>/src/handlers","prompt":""}'
CTX=$(echo "$INPUT" | "$HOOK" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -q "Archetype: telegram-bot"; then
  echo "FAIL: prefix match should resolve to telegram-bot. Got: $CTX" >&2
  exit 1
fi
echo "PASS"
