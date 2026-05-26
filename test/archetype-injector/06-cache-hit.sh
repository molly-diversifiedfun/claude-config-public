#!/usr/bin/env bash
# Test: second invocation with same cwd uses cache.
set -euo pipefail
HOOK="$HOME/.claude/hooks/archetype-injector.sh"
CACHE="$HOME/.claude/checkpoints/archetype-cache.json"

# Clear cache
rm -f "$CACHE"

INPUT='{"cwd":"$HOME/github/nancy","prompt":""}'

# First invocation
echo "$INPUT" | "$HOOK" >/dev/null

if [ ! -f "$CACHE" ]; then
  echo "FAIL: cache file not created after first invocation" >&2
  exit 1
fi

# Cache should contain the cwd → archetype mapping
if ! jq -e '.["$HOME/github/nancy"]' "$CACHE" >/dev/null 2>&1; then
  echo "FAIL: cache missing key for nancy. Got: $(cat "$CACHE")" >&2
  exit 1
fi

ARCH=$(jq -r '.["$HOME/github/nancy"].archetype' "$CACHE")
if [ "$ARCH" != "telegram-bot" ]; then
  echo "FAIL: expected cached archetype=telegram-bot, got: $ARCH" >&2
  exit 1
fi

echo "PASS"
