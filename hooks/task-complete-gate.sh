#!/bin/bash
# task-complete-gate.sh — TaskCompleted hook (command type)
# Replaces the old LLM-prompt hook that burned tokens to almost always return {}.
# Default: ALLOW. Only blocks when task subject is a literal command form
# ("Run X", "Execute X", "Deploy X") AND no evidence of execution in context.
# Kill switch: TASK_COMPLETE_GATE=off

[ "${TASK_COMPLETE_GATE:-on}" = "off" ] && echo '{}' && exit 0

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && echo '{}' && exit 0

SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // .subject // ""' 2>/dev/null)
[ -z "$SUBJECT" ] && echo '{}' && exit 0

SUBJECT_LOWER=$(echo "$SUBJECT" | tr '[:upper:]' '[:lower:]')

# Only trigger on literal command-form subjects
if ! echo "$SUBJECT_LOWER" | grep -qE '^(run |execute |deploy to )'; then
  echo '{}'
  exit 0
fi

# If context contains any evidence of tool execution, allow
CONTEXT=$(echo "$INPUT" | jq -r '.context // .conversation // ""' 2>/dev/null)
if [ -n "$CONTEXT" ]; then
  CONTEXT_LOWER=$(echo "$CONTEXT" | tr '[:upper:]' '[:lower:]')
  if echo "$CONTEXT_LOWER" | grep -qE '(exit.code|tool_result|command.*output|\$ |>>> |passed|succeeded|deployed)'; then
    echo '{}'
    exit 0
  fi
fi

printf '{"decision":"block","reason":"Task subject looks like a command (%s) but no execution evidence found. Kill: TASK_COMPLETE_GATE=off"}\n' "$SUBJECT"
exit 0
