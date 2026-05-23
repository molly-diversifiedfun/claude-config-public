#!/usr/bin/env bash
# Test: SKILL_INJECTION=off → no skill block; learned/ + always-on render normal.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"hello"}'

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | SKILL_INJECTION=off "$HOOK" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC)" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if echo "$CTX" | grep -qE "🛠 Likely-useful skills"; then
  echo "FAIL: skill block present despite SKILL_INJECTION=off. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -qE "Relevant learned/ patterns this session"; then
  echo "FAIL: learned/ block missing — kill switch was overly broad. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -qE "Always-on \(severity=blocking\)"; then
  echo "FAIL: always-on block missing — kill switch was overly broad. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
