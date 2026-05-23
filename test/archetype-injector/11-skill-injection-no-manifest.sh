#!/usr/bin/env bash
# Test: skill-archetypes.yaml missing → no skill block; learned/ + always-on intact.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"hello"}'

# Temporarily hide the manifest
ORIG_MANIFEST="$HOME/.claude/skill-archetypes.yaml"
BACKUP="/tmp/test-11-manifest.yaml.bak"
mv "$ORIG_MANIFEST" "$BACKUP" 2>/dev/null || true

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"
OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
RC=$?

# Restore
if [ -f "$BACKUP" ]; then
  mv "$BACKUP" "$ORIG_MANIFEST"
fi
rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC) without manifest. Got:" >&2
  echo "$OUT" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if echo "$CTX" | grep -qE "🛠 Likely-useful skills"; then
  echo "FAIL: skill block present despite missing manifest. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

if ! echo "$CTX" | grep -qE "Relevant learned/ patterns this session"; then
  echo "FAIL: learned/ block missing — hook broke without manifest. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
