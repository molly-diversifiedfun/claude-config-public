#!/bin/bash
# pre-commit-checks.sh — BLOCKS commits with missing tests for new code
#
# Receives JSON on stdin from Claude Code PreToolUse hook.
# Only fires on `git commit` commands — exits silently for everything else.
# Exit 0 = allow, Exit 2 = block with message.
#
# Kill switch: PRECOMMIT_GATE=off <command>

set -uo pipefail

# Kill switch — fail-open if explicitly disabled
if [[ "${PRECOMMIT_GATE:-on}" == "off" ]]; then
  exit 0
fi

# Shared block logger (no-op if lib missing)
source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null || true

# Read JSON from stdin
INPUT=$(cat)

# Extract the command from tool input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Exit silently if not a git commit
if ! echo "$COMMAND" | grep -qE '^\s*git\s+commit\b'; then
  exit 0
fi

# We're in a git commit — run checks against staged files
ERRORS=""
WARNINGS=""

# ─── Check: Remote is not ahead (avoid push failures) ───
git fetch --quiet 2>/dev/null || true
LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
BASE=$(git merge-base HEAD @{u} 2>/dev/null || echo "")
if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ] && [ "$LOCAL" = "$BASE" ]; then
  WARNINGS="${WARNINGS}\n⚠️  Remote is ahead of local. Run 'git pull --rebase' before committing to avoid push failures."
fi

# ─── Check: Biome format on staged files (catches CI failures) ───
STAGED_TS=$(git diff --cached --name-only 2>/dev/null | grep -E '\.(ts|tsx|js|jsx)$' || true)
if [ -n "$STAGED_TS" ]; then
  FORMAT_CHECK=$(echo "$STAGED_TS" | xargs npx biome check --diagnostic-level=error 2>&1 | grep "Found [0-9]* error" || true)
  if echo "$FORMAT_CHECK" | grep -q "Found [1-9]"; then
    ERRORS="${ERRORS}\n🚫 BIOME CHECK FAILED — run 'npx biome format --write && npx biome check --fix' before committing.\n${FORMAT_CHECK}"
  fi
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null || true)

# Check if this is a docs/chore/test-only commit (skip test checks for non-code commits)
IS_CODE_COMMIT=true
if echo "$COMMAND" | grep -qE '(docs|chore|test|ci):'; then
  IS_CODE_COMMIT=false
fi

# ─── Check: New source files must have corresponding test files ───
if [ "$IS_CODE_COMMIT" = "true" ]; then
  MISSING_TESTS=""

  # Check components (.tsx)
  for f in $(echo "$STAGED" | grep -E "src/(components|pages)/.*\.tsx$" | grep -v ".test." | grep -v "__" || true); do
    # Skip index files, types, constants
    base=$(basename "$f")
    if echo "$base" | grep -qiE "^(index|types|constants)\."; then
      continue
    fi

    # Look for test file with same name
    TEST_TSX="${f%.tsx}.test.tsx"
    TEST_TS="${f%.tsx}.test.ts"
    if ! echo "$STAGED" | grep -qE "(${TEST_TSX}|${TEST_TS})"; then
      if [ ! -f "$TEST_TSX" ] && [ ! -f "$TEST_TS" ]; then
        MISSING_TESTS="${MISSING_TESTS}\n  - ${f}"
      fi
    fi
  done

  # Check services (.ts)
  for f in $(echo "$STAGED" | grep -E "src/services/.*\.ts$" | grep -v ".test." | grep -v "__" || true); do
    TEST_FILE="${f%.ts}.test.ts"
    TEST_DIR=$(dirname "$f")/__tests__/$(basename "${f%.ts}").test.ts
    if ! echo "$STAGED" | grep -q "$TEST_FILE"; then
      if [ ! -f "$TEST_FILE" ] && [ ! -f "$TEST_DIR" ]; then
        MISSING_TESTS="${MISSING_TESTS}\n  - ${f}"
      fi
    fi
  done

  # Check hooks (.ts/.tsx)
  for f in $(echo "$STAGED" | grep -E "src/hooks/.*\.(ts|tsx)$" | grep -v ".test." || true); do
    TEST_TS="${f%.ts}.test.ts"
    TEST_TSX="${f%.tsx}.test.tsx"
    if ! echo "$STAGED" | grep -qE "(${TEST_TS}|${TEST_TSX})"; then
      if [ ! -f "$TEST_TS" ] && [ ! -f "$TEST_TSX" ]; then
        MISSING_TESTS="${MISSING_TESTS}\n  - ${f}"
      fi
    fi
  done

  if [ -n "$MISSING_TESTS" ]; then
    ERRORS="${ERRORS}\n🚫 NEW CODE WITHOUT TESTS — tests must ship in the same commit:\n${MISSING_TESTS}\n\nCreate test files for each, then stage them with the commit.\nSee CLAUDE.md Coding Standard #9."
  fi
fi

# ─── Warning: Doc updates (non-blocking) ───

# New edge function without doc update
if echo "$STAGED" | grep -q "supabase/functions/.*/index.ts"; then
  if ! echo "$STAGED" | grep -q "docs/edge-functions.md"; then
    WARNINGS="${WARNINGS}\n⚠️  New edge function staged but docs/edge-functions.md not updated"
  fi
fi

# New migration without schema doc update
if echo "$STAGED" | grep -q "supabase/migrations/"; then
  if ! echo "$STAGED" | grep -q "docs/database-schema.md"; then
    WARNINGS="${WARNINGS}\n⚠️  New migration staged but docs/database-schema.md not updated"
  fi
fi

# ─── /ship Stage 10 enforcement (Phase 8.0.3, 2026-05-23) ───
# When a /ship run is in progress (.ship/<run>/scope.json exists), Stage 10
# requires HANDOFF.md + CLAUDE.md updates for scope != S. /system-retro
# 2026-05-23 found "Process Documentation Left Behind" was the most-common
# gap on /ship sessions specifically — Stage 10's "AUTO-EXECUTE project-manager"
# was a fiction (orchestrator did docs inline or skipped them). This warns
# (not blocks) at commit time when a /ship scope expects docs and they're
# missing from the staged set.
SHIP_SCOPE_FILE=$(ls -t .ship/*/scope.json 2>/dev/null | head -1)
if [ -n "$SHIP_SCOPE_FILE" ] && [ -f "$SHIP_SCOPE_FILE" ]; then
  SHIP_SCOPE=$(jq -r '.scope // empty' < "$SHIP_SCOPE_FILE" 2>/dev/null)
  if [ -n "$SHIP_SCOPE" ] && [ "$SHIP_SCOPE" != "S" ]; then
    # docs/chore/test commits exempt per the IS_CODE_COMMIT logic above
    if [ "$IS_CODE_COMMIT" = "true" ]; then
      if ! echo "$STAGED" | grep -qE '(^|/)HANDOFF\.md$'; then
        WARNINGS="${WARNINGS}\n⚠️  /ship Stage 10: scope=$SHIP_SCOPE expects HANDOFF.md update (not in staged set: ${SHIP_SCOPE_FILE})"
      fi
      if ! echo "$STAGED" | grep -qE '(^|/)CLAUDE\.md$'; then
        WARNINGS="${WARNINGS}\n⚠️  /ship Stage 10: scope=$SHIP_SCOPE expects CLAUDE.md update when shipping new behavior (not in staged set)"
      fi
    fi
  fi
fi

# ─── Output ───

if [ -n "$WARNINGS" ]; then
  echo -e "\n📋 Pre-commit warnings:${WARNINGS}\n" >&2
fi

if [ -n "$ERRORS" ]; then
  echo -e "${ERRORS}" >&2
  echo "  Kill switch: PRECOMMIT_GATE=off <command>" >&2
  type log_block >/dev/null 2>&1 && log_block "BLOCKED: pre-commit check failed: $(echo "$ERRORS" | head -c 200)" "PRECOMMIT_GATE"
  exit 2
fi

exit 0
