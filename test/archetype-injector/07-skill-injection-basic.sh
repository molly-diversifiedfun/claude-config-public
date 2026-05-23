#!/usr/bin/env bash
# Test: skill-archetypes.yaml present + matching archetype → skill block in output.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"

# claude-config dir → infra-config archetype
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"hello"}'

# Bust cache so this test reflects current manifest state
rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC): $OUT" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -qE "🛠 Likely-useful skills"; then
  echo "FAIL: expected '🛠 Likely-useful skills' header in context. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Should include at least one infra-config-tagged skill (carl-manager per seed)
if ! echo "$CTX" | grep -qE "carl-manager"; then
  echo "FAIL: expected 'carl-manager' in skill block. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Should still include learned/ patterns block (regression check)
if ! echo "$CTX" | grep -qE "Relevant learned/ patterns this session"; then
  echo "FAIL: expected learned/ block to STILL be present. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
