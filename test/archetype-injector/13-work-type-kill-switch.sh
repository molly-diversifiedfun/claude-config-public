#!/usr/bin/env bash
# Test: WORKTYPE_GATE=off → no 🧭 block; archetype + learned/ blocks intact.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"lets brainstorm a new feature"}'

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | WORKTYPE_GATE=off "$HOOK" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC)" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if echo "$CTX" | grep -qE "🧭 Work-type detected"; then
  echo "FAIL: 🧭 block present despite WORKTYPE_GATE=off. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -qE "Relevant learned/ patterns"; then
  echo "FAIL: learned/ block missing — kill switch overly broad. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -qE "🛠 Likely-useful skills"; then
  echo "FAIL: archetype-skills block missing — kill switch overly broad. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
