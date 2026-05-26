#!/bin/bash
# agent-batch-validator.sh — PreToolUse hook (matcher: Agent)
# Blocks agent dispatch if the prompt references too many OPERATIONAL files (>MAX).
# Enforces CARL GLOBAL_RULE_3: "max 3-4 files per agent" for batch file operations.
#
# Routine reference docs (memory files, HANDOFF.md, .ship/ artifacts, ADRs)
# do NOT count — they're citations the agent reads for context, not files it processes.
#
# Input: JSON on stdin { "tool_name": "Agent", "tool_input": { "prompt": "...", "description": "..." } }
# Output: exit 0 = allow, exit 2 = block with feedback message
# Kill switch: BATCH_GATE=off

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

if [ "$TOOL_NAME" != "Agent" ]; then
  exit 0
fi

# Kill switch
if [ "${BATCH_GATE:-on}" = "off" ]; then
  exit 0
fi

PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

# Phase 8.x adjustment (2026-05-24): strip fenced code blocks before counting.
# Paths inside ```...``` blocks are code content (test fixtures, example commands),
# not files the agent navigates to. Without this, dual-write patterns + test
# fixtures + canonical YAML examples blow the limit on every dispatch.
PROMPT_PROSE=$(echo "$PROMPT" | awk '
  /^```/ { in_block = !in_block; next }
  !in_block { print }
')

# Allowlist: routine reference docs that don't count toward the operational limit.
# Citations / memory files / run artifacts / ADRs / orientation docs.
ALLOWLIST_REGEX='(^|/)(MEMORY|HANDOFF|TASKS|CLAUDE|CHANGELOG|README|AGENTS|GEMINI)\.md$|(^|/)(feedback|project|reference|user)_[^/]+\.md$|/\.ship/[^/]+/[^/]*\.md$|/docs/decisions/[^/]+\.md$|/docs/audit/[^/]+\.md$|/\.claude/rules/[^/]+\.md$|(^|/)(patterns|spec|deploy-log|handoff-draft|TODO|NOTES)\.md$'

# Collect prefix-matched file paths (src/foo.ts, docs/bar.md, supabase/baz.sql)
PREFIX_FILES=$(echo "$PROMPT_PROSE" | grep -oE '(src/|docs/|supabase/)[^ ]+\.(ts|tsx|md|sql|js|jsx)' | sort -u)

# Collect backticked files (any path in backticks ending in known extensions, strip backticks)
BACKTICK_FILES=$(echo "$PROMPT_PROSE" | grep -oE '`[^`]+\.(ts|tsx|md|sql|js|jsx)`' | tr -d '`' | sort -u)

# Merge
ALL_REFS=$(printf '%s\n%s\n' "$PREFIX_FILES" "$BACKTICK_FILES" | grep -v '^$' | sort -u)

# Phase 8.x adjustment (2026-05-24): canonicalize paths before dedup.
# `~/foo` and `$HOME/foo` and absolute `/Users/.../foo` are the same file.
# Also strip `$VAR/`-prefixed paths — those are template variables, not real files.
CANONICAL_REFS=$(echo "$ALL_REFS" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  # Skip template-variable paths ($TMP/foo, etc.)
  if [ "${p:0:1}" = '$' ]; then continue; fi
  # Normalize ~/ → $HOME/
  if [ "${p:0:2}" = '~/' ]; then p="$HOME/${p:2}"; fi
  echo "$p"
done | sort -u)

# Filter allowlist — only count operational refs
OPERATIONAL_REFS=$(echo "$CANONICAL_REFS" | grep -vE "$ALLOWLIST_REGEX" || true)
FILE_COUNT=$(echo "$OPERATIONAL_REFS" | grep -v '^$' | wc -l | tr -d ' ')

MAX_FILES=6

if [ "$FILE_COUNT" -gt "$MAX_FILES" ]; then
  echo "⚠️  BATCH SIZE: This agent prompt references $FILE_COUNT operational files (max $MAX_FILES per CARL GLOBAL_RULE_3)." >&2
  echo "" >&2
  echo "Operational files counted (routine reference docs are allowlisted — see hook source):" >&2
  echo "$OPERATIONAL_REFS" | head -10 | sed 's/^/  • /' >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  1. Split into multiple parallel agents with ≤6 files each." >&2
  echo "  2. Replace explicit paths with 'grep for X' / 'find files matching Y' patterns." >&2
  echo "  3. Kill switch for this session: export BATCH_GATE=off" >&2
  exit 2
fi

# Scope-fidelity check (feedback_stop_narrowing_scope, feedback_dont_narrow_employee_scope)
if [ "${SCOPE_GATE:-on}" != "off" ]; then
  LAST_PROMPT_FILE="$HOME/.claude/checkpoints/last_prompt"
  if [ -f "$LAST_PROMPT_FILE" ]; then
    LAST_PROMPT=$(cat "$LAST_PROMPT_FILE")
    LAST_PROMPT_LOWER=$(echo "$LAST_PROMPT" | tr '[:upper:]' '[:lower:]')

    SCOPE_REGEX='\b(all|every|each|across|both|multiple)\s+(\w+\s+){0,2}(brands|projects|posts|files|deliverables|chapters|clients|scripts|tools|hooks|rules|agents|mechanisms|items|options|channels|platforms|audiences|users|skills|domains|patterns|memories|learnings)\b'
    SCOPE_MATCH=$(echo "$LAST_PROMPT_LOWER" | grep -oE "$SCOPE_REGEX" | head -1)

    EXCLUDE_HIT=false
    for excl in "all done" "all good" "all set" "every time" "every now" "each iteration" "each time" "across the board"; do
      if [[ "$LAST_PROMPT_LOWER" == *"$excl"* ]]; then EXCLUDE_HIT=true; break; fi
    done

    if [ -n "$SCOPE_MATCH" ] && [ "$EXCLUDE_HIT" = "false" ]; then
      PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
      HAS_SCOPE_LINE=false
      if echo "$PROMPT" | grep -qiE '^[[:space:]]*scope[[:space:]]*[:]'; then HAS_SCOPE_LINE=true; fi
      if echo "$PROMPT" | grep -qiE '^[[:space:]]*##[[:space:]]*scope'; then HAS_SCOPE_LINE=true; fi
      if [[ "$PROMPT_LOWER" == *"$SCOPE_MATCH"* ]]; then HAS_SCOPE_LINE=true; fi

      if [ "$HAS_SCOPE_LINE" = "false" ]; then
        echo "⚠️  SCOPE-FIDELITY: Your last user message contained scope tokens" >&2
        echo "(matched: \"$SCOPE_MATCH\"), but this agent prompt doesn't restate scope." >&2
        echo "" >&2
        echo "This is the pattern from feedback_stop_narrowing_scope.md and" >&2
        echo "feedback_dont_narrow_employee_scope.md — silent narrowing at delegation." >&2
        echo "" >&2
        echo "Add a \"Scope: [item1, item2, item3, ...]\" line to the agent prompt" >&2
        echo "listing the full scope from the user request. Then re-dispatch." >&2
        echo "" >&2
        echo "Kill switch (this session): export SCOPE_GATE=off" >&2
        exit 2
      fi
    fi
  fi
fi

exit 0
