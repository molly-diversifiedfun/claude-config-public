#!/bin/bash
# log-block.sh — shared logging helper for hook blocks.
#
# Usage: source this from a hook, then call `log_block "<reason>" "<gate_name>"` BEFORE exit 2.
# Output: appends one JSON line to $HOME/.claude/logs/hook-blocks.log per call.
#
# Schema:
#   {"ts":"...","hook":"<name>","gate":"<env_var>","cwd":"<dir>","reason":"<short>"}
#
# Reason is truncated to 500 chars + newlines stripped. cwd + reason are JSON-escaped.
# Fails open: if anything errors (mkdir, write, jq missing), the calling hook continues
# its normal exit path — logging never blocks the hook itself.

LOG_BLOCK_FILE="${LOG_BLOCK_FILE:-$HOME/.claude/logs/hook-blocks.log}"

log_block() {
  local reason="${1:-}"
  local gate="${2:-}"
  local hook_name ts cwd_safe reason_safe

  # Identify the calling hook (basename of the script that sourced this lib).
  # BASH_SOURCE[1] is the sourcer; fall back to $0 if that's empty (POSIX shells).
  hook_name=$(basename "${BASH_SOURCE[1]:-$0}" 2>/dev/null)

  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || ts="unknown"
  cwd_safe=$(pwd 2>/dev/null | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n')
  reason_safe=$(printf '%s' "$reason" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g' | cut -c1-500)

  mkdir -p "$(dirname "$LOG_BLOCK_FILE")" 2>/dev/null || return 0
  printf '{"ts":"%s","hook":"%s","gate":"%s","cwd":"%s","reason":"%s"}\n' \
    "$ts" "$hook_name" "$gate" "$cwd_safe" "$reason_safe" \
    >> "$LOG_BLOCK_FILE" 2>/dev/null || return 0
}
