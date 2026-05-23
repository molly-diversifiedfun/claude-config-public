#!/usr/bin/env bash
# Test: prompt with "brainstorm" verb → 🧭 plan block emits the plan chain.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"lets brainstorm a new feature"}'

# Bust cache so detection actually runs (cache wouldn't include work-type anyway,
# but bust to keep test deterministic)
rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: hook exited non-zero ($RC): $OUT" >&2
  exit 1
fi

CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

# Must include the work-type block header
if ! echo "$CTX" | grep -qE "🧭 Work-type detected: plan"; then
  echo "FAIL: expected '🧭 Work-type detected: plan' header. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Must include the plan chain's first skill (superpowers:brainstorming)
if ! echo "$CTX" | grep -qE "1\. superpowers:brainstorming"; then
  echo "FAIL: expected '1. superpowers:brainstorming' as first chain entry. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

# Must STILL include the existing archetype-skills block (regression check)
if ! echo "$CTX" | grep -qE "🛠 Likely-useful skills"; then
  echo "FAIL: archetype-skills block missing — 7.1 regression. Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
