#!/bin/bash
# surface-hook-blocks.sh — SessionStart hook.
# Reads ~/.claude/logs/hook-blocks.log and emits a systemMessage if any blocks
# happened in the last 24 hours. Helps catch hook false-positives across sessions.
#
# Kill switch: SURFACE_HOOK_BLOCKS=off  (silences the surface, log keeps growing)

LOG_BLOCK_FILE="${LOG_BLOCK_FILE:-$HOME/.claude/logs/hook-blocks.log}"

# Kill switch
if [ "${SURFACE_HOOK_BLOCKS:-on}" = "off" ]; then
  echo '{}'
  exit 0
fi

# No log file → nothing to surface
if [ ! -f "$LOG_BLOCK_FILE" ]; then
  echo '{}'
  exit 0
fi

# 24h cutoff (UTC ISO 8601)
CUTOFF=$(date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
if [ -z "$CUTOFF" ]; then
  echo '{}'
  exit 0
fi

# Slurp NDJSON, filter to last 24h, summarize.
# Fail-open: if jq missing or malformed log, emit empty and continue.
SUMMARY=$(jq -rs --arg cutoff "$CUTOFF" '
  [.[] | select(.ts >= $cutoff)] as $recent
  | if ($recent | length) == 0 then ""
    else
      ($recent | length | tostring) + " hook block(s) in last 24h: " +
      ($recent | group_by(.hook) | map((.[0].hook) + " (" + (length | tostring) + ")") | join(", "))
    end
' "$LOG_BLOCK_FILE" 2>/dev/null)

if [ -n "$SUMMARY" ]; then
  # Escape for embedding in JSON systemMessage
  SUMMARY_ESC=$(printf '%s' "$SUMMARY" | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo "{\"systemMessage\":\"⚠️  ${SUMMARY_ESC}. Review ~/.claude/logs/hook-blocks.log; TaskCreate any false positives per react-to-hook-errors-in-tool-results rule.\"}"
else
  echo '{}'
fi
exit 0
