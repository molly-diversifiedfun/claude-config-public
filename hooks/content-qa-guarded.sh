#!/bin/bash
# content-qa.sh — PostToolUse hook for Write|Edit
# Checks content files for PM jargon, tool mention limits, and AI tells.
# PATH GUARD: exits early if the edited file is NOT a content file.

# Parse input
INPUT=$(cat 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // ""' 2>/dev/null)

# ============================================================
# PATH GUARD — exit early for non-content files
# ============================================================
# Only run QA on content files (captions, carousels, posts, calendars)
case "$FILE_PATH" in
  */<your-content-pipeline>/*)  ;; # content system repo — check it
  */<your-first-brand-slug>/*)         ;; # <your-first-brand> content — check it
  */captions/*)        ;; # caption files — check it
  */posts/*)           ;; # post files — check it
  */carousels/*)       ;; # carousel files — check it
  */memes/*)           ;; # meme files — check it
  */content-calendar*) ;; # calendar files — check it
  *)
    # Not a content file — skip QA
    echo '{}'
    exit 0
    ;;
esac

# Also skip non-text files
case "$FILE_PATH" in
  *.md|*.txt|*.json|*.html|*.yml|*.yaml) ;; # text files — check
  *.ts|*.tsx|*.js|*.jsx)                  ;; # could contain caption strings
  *.py)                                   ;; # scripts that generate content
  *)
    echo '{}'
    exit 0
    ;;
esac

# ============================================================
# QA CHECKS
# ============================================================

WARNINGS=""

if [ -f "$FILE_PATH" ]; then
  CONTENT=$(cat "$FILE_PATH" 2>/dev/null)

  # Check for PM jargon (banned in Instagram content)
  PM_JARGON=$(echo "$CONTENT" | grep -iwon '\bscope\b\|\bsprint\b\|\bstandup\b\|\bdecompose\b\|\bbacklog\b\|\broadmap\b\|\bRICE\b' | head -5)
  if [ -n "$PM_JARGON" ]; then
    WARNINGS="${WARNINGS}PM jargon found: $(echo "$PM_JARGON" | tr '\n' ', '). "
  fi

  # Check for tool mention clustering (max 1 per specific tool)
  for TOOL in Notion Figma "VS Code" Cursor Vercel Railway Supabase Stripe Linear Airtable; do
    COUNT=$(echo "$CONTENT" | grep -io "\b${TOOL}\b" | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 1 ]; then
      WARNINGS="${WARNINGS}Tool '${TOOL}' mentioned ${COUNT} times (max 1). "
    fi
  done

  # Check for AI number tell
  COUNT_47=$(echo "$CONTENT" | grep -o '\b47\b' | wc -l | tr -d ' ')
  if [ "$COUNT_47" -gt 0 ]; then
    WARNINGS="${WARNINGS}Number '47' found ${COUNT_47} time(s) — known AI tell. "
  fi

  # Check Instagram handle
  WRONG_HANDLE=$(echo "$CONTENT" | grep -io '@your-wrong-handle-2\|@your-wrong-handle' | head -1)
  if [ -n "$WRONG_HANDLE" ]; then
    WARNINGS="${WARNINGS}Wrong handle '${WRONG_HANDLE}' — use @your-handle. "
  fi
fi

if [ -n "$WARNINGS" ]; then
  WARNINGS_ESCAPED=$(echo "$WARNINGS" | sed 's/"/\\"/g')
  echo "{\"systemMessage\":\"CONTENT QA: ${WARNINGS_ESCAPED}\"}"
else
  echo '{}'
fi

exit 0
