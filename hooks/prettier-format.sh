#!/bin/bash
# prettier-format.sh — PostToolUse hook (matcher: Write|Edit)
# Auto-formats JS/TS files after write/edit.
# Input: JSON on stdin from Claude Code hook system

INPUT=$(cat 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx)
    npx prettier --write "$FILE_PATH" 2>/dev/null || true
    ;;
esac

exit 0
