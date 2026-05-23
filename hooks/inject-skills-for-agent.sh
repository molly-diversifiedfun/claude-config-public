#!/usr/bin/env bash
# inject-skills-for-agent.sh — PreToolUse:Agent hook (Phase 7.5)
# Runs scripts/skills-prefilter.sh on the dispatch description and injects
# the top-3 candidates into the subagent's prompt as a context block.
#
# Allowlisted subagents (only these get injection):
#   engineer designer debugger content-social content-longform content-business tech-researcher
#
# Input: JSON on stdin: {"tool_name":"Agent","tool_input":{"subagent_type":...,"description":...,"prompt":...}}
# Output (Mechanism A — Claude Code PreToolUse spec): JSON on stdout with
#   hookSpecificOutput.updatedInput.prompt (full prompt with skill block prepended).
# Soft-fails open on every internal error — never blocks dispatch.
#
# Kill switch: SKILL_INJECT_FOR_AGENT=off
# Log: ~/.claude/logs/inject-skills-for-agent.log (NDJSON, one line per fire/skip)

set +e

LOG="$HOME/.claude/logs/inject-skills-for-agent.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log_outcome() {
  local subagent="$1"
  local query="$2"
  local outcome="$3"
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local query_short="${query:0:80}"
  printf '{"ts":"%s","subagent_type":"%s","query":"%s","outcome":"%s"}\n' \
    "$ts" "$subagent" "$query_short" "$outcome" >> "$LOG" 2>/dev/null
}

# Read stdin
INPUT=$(cat 2>/dev/null)
if [ -z "$INPUT" ]; then exit 0; fi

# Defensive: only fire on Agent tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL_NAME" != "Agent" ]; then exit 0; fi

# Kill switch
if [ "${SKILL_INJECT_FOR_AGENT:-on}" = "off" ]; then
  log_outcome "?" "" "skipped:kill_switch"
  exit 0
fi

# Allowlist check
SUBAGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)
case "$SUBAGENT" in
  engineer|designer|debugger|content-social|content-longform|content-business|tech-researcher)
    ;;
  *)
    log_outcome "$SUBAGENT" "" "skipped:not_allowlisted"
    exit 0
    ;;
esac

# Extract query: description first, fall back to prompt[:200]
DESC=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

QUERY="$DESC"
if [ -z "$QUERY" ]; then
  QUERY="${PROMPT:0:200}"
fi

if [ -z "$QUERY" ]; then
  log_outcome "$SUBAGENT" "" "skipped:empty_query"
  exit 0
fi

# Run prefilter
PREFILTER_OUT=$(bash "$HOME/.claude/scripts/skills-prefilter.sh" "$QUERY" 2>/dev/null)
PREFILTER_RC=$?

if [ "$PREFILTER_RC" -ne 0 ] || [ -z "$PREFILTER_OUT" ]; then
  log_outcome "$SUBAGENT" "$QUERY" "skipped:prefilter_error"
  exit 0
fi

# Parse top-3 candidates (skip header lines starting with #)
CANDIDATES=$(echo "$PREFILTER_OUT" | grep -vE '^#' | head -3)
COUNT=$(echo "$CANDIDATES" | grep -cE '\|')

if [ "$COUNT" -lt 3 ]; then
  log_outcome "$SUBAGENT" "$QUERY" "skipped:fewer_than_3_candidates"
  exit 0
fi

# Format injection block. Each prefilter line: <name>|<archetypes>|<description>|<untried>
BLOCK="<!-- phase-7-5-injected-skills v1 -->"$'\n'"[Relevant skills for this task (Phase 7.5 prefilter):]"$'\n'
while IFS= read -r line; do
  [ -z "$line" ] && continue
  NAME=$(echo "$line" | awk -F'|' '{print $1}')
  DESC_EXCERPT=$(echo "$line" | awk -F'|' '{print $3}')
  BLOCK="${BLOCK}- ${NAME} — ${DESC_EXCERPT}"$'\n'
done <<< "$CANDIDATES"
BLOCK="${BLOCK}"$'\n'"(Consider using one of these before reinventing.)"$'\n'"<!-- /phase-7-5-injected-skills -->"

# Mechanism A: emit hookSpecificOutput with updatedInput prepending the block.
# Field name per Claude Code PreToolUse hooks spec (code.claude.com/docs/en/hooks.md):
#   hookSpecificOutput.updatedInput is an object merged into tool_input.
NEW_PROMPT="${BLOCK}

${PROMPT}"

jq -n --arg np "$NEW_PROMPT" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: {prompt: $np}}}' 2>/dev/null

log_outcome "$SUBAGENT" "$QUERY" "injected"
exit 0
