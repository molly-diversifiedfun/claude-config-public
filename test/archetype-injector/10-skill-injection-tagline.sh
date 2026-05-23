#!/usr/bin/env bash
# Test: skill block entries include 60-char tagline from SKILL.md description.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"

# Use a real installed personal skill we know has a description: "handoff" (tagged always-on)
INPUT='{"cwd":"$HOME/no-such-dir","prompt":"hello"}'
rm -f "$HOME/.claude/checkpoints/archetype-cache.json"
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

# handoff is tagged always-on per seed manifest → should appear with tagline
LINE=$(echo "$CTX" | grep -E '^[[:space:]]+- handoff' | head -1)

if [ -z "$LINE" ]; then
  echo "FAIL: 'handoff' skill not surfaced. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Tagline format: '  - handoff — <description>' (em-dash separator)
if ! echo "$LINE" | grep -qE '— '; then
  echo "FAIL: expected '— <tagline>' on handoff entry, got: $LINE" >&2
  exit 1
fi

# Tagline should be ≤60 chars after the em-dash
TAGLINE=$(echo "$LINE" | sed -E 's/^[[:space:]]+- handoff — //')
TAGLEN=${#TAGLINE}
if [ "$TAGLEN" -gt 60 ]; then
  echo "FAIL: tagline length $TAGLEN exceeds 60. Got: $TAGLINE" >&2
  exit 1
fi

echo "PASS"
