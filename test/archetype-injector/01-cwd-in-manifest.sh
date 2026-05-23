#!/usr/bin/env bash
# Test: cwd exactly matches a manifest entry → expected archetype + relevant patterns surface.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"

INPUT='{"cwd":"$HOME/github/<your-bot>","prompt":"hello"}'
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC): $OUT" >&2
  exit 1
fi

if ! echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  echo "FAIL: missing additionalContext in output: $OUT" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -q "telegram-bot"; then
  echo "FAIL: expected 'telegram-bot' in context: $CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -q "bot-conversational-ux"; then
  echo "FAIL: expected 'bot-conversational-ux' pattern in context: $CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -q "never-fabricate"; then
  echo "FAIL: expected always-on 'never-fabricate' in context: $CTX" >&2
  exit 1
fi

echo "PASS"
