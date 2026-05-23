#!/usr/bin/env bash
# Test: prompt with no work-type keywords → no 🧭 block; everything else intact.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
# Deliberately ambiguous prompt — no verbs that match any pattern
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"hello there"}'

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC)" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if echo "$CTX" | grep -qE "🧭 Work-type detected"; then
  echo "FAIL: 🧭 block present on ambiguous prompt. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Archetype block must still render normally
if ! echo "$CTX" | grep -qE "🎯 Archetype: infra-config"; then
  echo "FAIL: archetype header missing on ambiguous-prompt path. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
