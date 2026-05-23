#!/usr/bin/env bash
# Test: detected work-type's chain renders numbered (1, 2, 3...) in yaml order.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
# "implement" should match the 'build' pattern
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"implement the new endpoint"}'

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -qE "🧭 Work-type detected: build"; then
  echo "FAIL: expected 'build' work-type detected. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Build chain per yaml: 1. test-driven-development, 2. subagent-driven-development, 3. verification-before-completion
CHAIN_BLOCK=$(echo "$CTX" | awk '/🧭 Work-type detected: build/,/🛠 Likely-useful|Always-on/')

FIRST=$(echo "$CHAIN_BLOCK" | grep -E '^  1\. ' | head -1)
SECOND=$(echo "$CHAIN_BLOCK" | grep -E '^  2\. ' | head -1)
THIRD=$(echo "$CHAIN_BLOCK" | grep -E '^  3\. ' | head -1)

if ! echo "$FIRST" | grep -qE 'superpowers:test-driven-development'; then
  echo "FAIL: entry 1 should be 'superpowers:test-driven-development'. Got: $FIRST" >&2
  exit 1
fi
if ! echo "$SECOND" | grep -qE 'superpowers:subagent-driven-development'; then
  echo "FAIL: entry 2 should be 'superpowers:subagent-driven-development'. Got: $SECOND" >&2
  exit 1
fi
if ! echo "$THIRD" | grep -qE 'superpowers:verification-before-completion'; then
  echo "FAIL: entry 3 should be 'superpowers:verification-before-completion'. Got: $THIRD" >&2
  exit 1
fi

echo "PASS"
