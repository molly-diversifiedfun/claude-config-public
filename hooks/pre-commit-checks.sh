#!/bin/bash
# pre-commit-checks.sh — BLOCKS commits with missing tests for new code
#
# Receives JSON on stdin from Claude Code PreToolUse hook.
# Only fires on `git commit` commands — exits silently for everything else.
# Exit 0 = allow, Exit 2 = block with message.

set -uo pipefail

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

# ─── Output ───

if [ -n "$WARNINGS" ]; then
  echo -e "\n📋 Pre-commit warnings:${WARNINGS}\n"
fi

if [ -n "$ERRORS" ]; then
  echo -e "${ERRORS}"
  exit 2
fi

exit 0
