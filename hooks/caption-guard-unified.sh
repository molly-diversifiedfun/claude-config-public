#!/usr/bin/env bash
# caption-guard-unified.sh — PreToolUse hook (matcher: Bash + Write|Edit)
#
# Unified caption guard. Two checks:
# 1. Bash: blocks freehand SQL caption INSERT/UPDATE without pipeline script
# 2. Write|Edit: blocks writes to unstuck/captions/** without reading the prompt
#
# Replaces: caption-guard.sh (Bash-only) + caption-pipeline-guard.sh (Write|Edit-only)
#
# Kill switch: CAPTION_GATE=off

set +e

if [[ "${CAPTION_GATE:-on}" == "off" ]]; then
  exit 0
fi

source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null || true

INPUT=$(cat 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# ── Check 1: Bash — freehand SQL caption writes ─────────────────────────
if [ "$TOOL" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

  if echo "$COMMAND" | grep -qi "supabase.*db.*query" && echo "$COMMAND" | grep -qi "SET caption"; then
    # Allow pipeline script or caption-generator references
    if echo "$COMMAND" | grep -q "produce-month\|stage_captions\|caption-generator"; then
      exit 0
    fi
    echo "BLOCKED: Freehand caption write via SQL. Use unstuck/prompts/caption-generator.md or python3 scripts/produce-month.py --stage=captions. Kill: CAPTION_GATE=off" >&2
    type log_block >/dev/null 2>&1 && log_block "BLOCKED: freehand caption SQL write" "CAPTION_GATE"
    exit 2
  fi
  exit 0
fi

# ── Check 2: Write|Edit — caption file writes without reading prompt ────
case "$TOOL" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

case "$FILE" in
  */unstuck/captions/*) ;;
  *) exit 0 ;;
esac

SESSION_LOG="${CLAUDE_SESSION_LOG:-/tmp/claude-session-tools.log}"
PROMPT_PATH="unstuck/prompts/caption-generator.md"

if [ -f "$SESSION_LOG" ] && grep -q "$PROMPT_PATH" "$SESSION_LOG"; then
  exit 0
fi

echo "BLOCKED: Writing to $FILE without reading $PROMPT_PATH. Read the prompt, fill the 5 inputs, then retry. Kill: CAPTION_GATE=off" >&2
type log_block >/dev/null 2>&1 && log_block "BLOCKED: caption file write without prompt read — $FILE" "CAPTION_GATE"
exit 2
