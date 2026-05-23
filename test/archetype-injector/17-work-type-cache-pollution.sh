#!/usr/bin/env bash
# Test: cache pollution regression — prompt 1 (no work-type match) populates
# cache; prompt 2 (matches 'brainstorm') on SAME cwd must still emit 🧭 block.
#
# Pre-fix (Phase 7.1.5 NIGHT-9): cached CTX baked-in the work-type from prompt 1,
# so prompt 2 received stale CTX (no 🧭 despite matching). Phase 7.1.5.1 caches
# BASE_CTX (no work-type) and finalize_ctx() injects work-type fresh at emit.
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
CWD="$HOME/github/claude-config"

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

# Prompt 1: ambiguous, populates cache with no 🧭 block
INPUT_1="{\"cwd\":\"$CWD\",\"prompt\":\"hello there\"}"
OUT_1=$(echo "$INPUT_1" | "$HOOK" 2>&1)
CTX_1=$(echo "$OUT_1" | jq -r '.hookSpecificOutput.additionalContext')

if echo "$CTX_1" | grep -qE "🧭 Work-type detected"; then
  echo "FAIL: prompt 1 should NOT have 🧭 block (ambiguous). Got:" >&2
  echo "$CTX_1" >&2
  exit 1
fi

# Prompt 2: SAME cwd, work-type-triggering. Cache will hit. 🧭 must still appear.
INPUT_2="{\"cwd\":\"$CWD\",\"prompt\":\"lets brainstorm a new feature\"}"
OUT_2=$(echo "$INPUT_2" | "$HOOK" 2>&1)
CTX_2=$(echo "$OUT_2" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX_2" | grep -qE "🧭 Work-type detected: plan"; then
  echo "FAIL: prompt 2 must show 🧭 block despite cache hit on cwd. Got:" >&2
  echo "$CTX_2" >&2
  exit 1
fi

if ! echo "$CTX_2" | grep -qE "1\. superpowers:brainstorming"; then
  echo "FAIL: prompt 2 must show chain entry. Got:" >&2
  echo "$CTX_2" >&2
  exit 1
fi

# Prompt 3: SAME cwd, different work-type. Verify the previous prompt didn't
# poison the cache with its 🧭 block (the bug we're guarding against).
INPUT_3="{\"cwd\":\"$CWD\",\"prompt\":\"debug why this is broken\"}"
OUT_3=$(echo "$INPUT_3" | "$HOOK" 2>&1)
CTX_3=$(echo "$OUT_3" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX_3" | grep -qE "🧭 Work-type detected: debug"; then
  echo "FAIL: prompt 3 must show 🧭 debug block (not stale plan from prompt 2). Got:" >&2
  echo "$CTX_3" >&2
  exit 1
fi

if echo "$CTX_3" | grep -qE "🧭 Work-type detected: plan"; then
  echo "FAIL: prompt 3 leaked stale 'plan' work-type from prompt 2's cache. Got:" >&2
  echo "$CTX_3" >&2
  exit 1
fi

echo "PASS"
