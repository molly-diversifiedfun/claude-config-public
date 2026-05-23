#!/usr/bin/env bash
set -euo pipefail
HOOK="$HOME/.claude/hooks/archetype-injector.sh"

INPUT='{"cwd":"/tmp","prompt":""}'
CTX=$(echo "$INPUT" | "$HOOK" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -q "Archetype: unknown"; then
  echo "FAIL: /tmp should resolve to unknown. Got: $CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -q "never-fabricate"; then
  echo "FAIL: blocking patterns should appear even on unknown. Got: $CTX" >&2
  exit 1
fi
echo "PASS"
