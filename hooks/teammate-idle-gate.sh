#!/bin/bash
# teammate-idle-gate.sh — TeammateIdle hook (command type)
# Replaces the old LLM-prompt hook that burned tokens to almost always return {}.
# Blocks only when teammate explicitly says work is unfinished or deferred.
# Kill switch: TEAMMATE_IDLE_GATE=off

[ "${TEAMMATE_IDLE_GATE:-on}" = "off" ] && echo '{}' && exit 0

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && echo '{}' && exit 0

MESSAGE=$(echo "$INPUT" | jq -r '.tool_response.content // .message // ""' 2>/dev/null)
[ -z "$MESSAGE" ] && echo '{}' && exit 0

MESSAGE_LOWER=$(echo "$MESSAGE" | tr '[:upper:]' '[:lower:]')

if echo "$MESSAGE_LOWER" | grep -qE '\b(unfinished|not done|deferred|incomplete|still working|not yet complete|work remaining)\b'; then
  printf '{"decision":"block","reason":"Teammate indicated work is unfinished. Kill: TEAMMATE_IDLE_GATE=off"}\n'
  exit 0
fi

echo '{}'
exit 0
