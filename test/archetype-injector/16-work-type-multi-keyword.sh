#!/usr/bin/env bash
# Test: prompt with multiple work-type signals → first-match per WORK_TYPE_ORDER wins.
# WORK_TYPE_ORDER is: plan > build > debug > review > research > write-content > memory > design > infra
# A prompt with BOTH "brainstorm" (plan) AND "debug" should pick PLAN (earlier in order).
set -euo pipefail

HOOK="$HOME/.claude/hooks/archetype-injector.sh"
INPUT='{"cwd":"$HOME/github/claude-config","prompt":"brainstorm how to debug this issue"}'

rm -f "$HOME/.claude/checkpoints/archetype-cache.json"

OUT=$(echo "$INPUT" | "$HOOK" 2>&1)
CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext')

if ! echo "$CTX" | grep -qE "🧭 Work-type detected: plan"; then
  echo "FAIL: expected 'plan' to win over 'debug' (plan is earlier in WORK_TYPE_ORDER). Got:" >&2
  echo "$CTX" >&2
  exit 1
fi

echo "PASS"
