#!/bin/bash
# block-dangerous.sh — PreToolUse hook (matcher: Bash)
# Blocks dangerous commands. Exits non-zero to block, zero to allow.
# Input: JSON on stdin from Claude Code hook system

# Parse command from stdin JSON (Claude Code passes hook data via stdin, not env vars)
INPUT=$(cat 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# If we couldn't parse the command, allow (fail-open to avoid breaking session)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Patterns to block. Regex (use with grep -E).
# Old prefix-match patterns ("rm -rf /") false-positived on every absolute-path
# delete (e.g. `rm -rf $HOME/.claude/skills/foo`). New patterns
# target only catastrophic forms: bare root, bare home, or root/home followed
# by * or --. Specific-path deletes are allowed.
DANGEROUS_PATTERNS=(
  'rm[[:space:]]+-rf[[:space:]]+/[[:space:]]*$'                 # rm -rf / (bare root)
  'rm[[:space:]]+-rf[[:space:]]+/[[:space:]]+(\*|--)'            # rm -rf / *  or  rm -rf / --
  'rm[[:space:]]+-rf[[:space:]]+/\*'                             # rm -rf /*
  'rm[[:space:]]+-rf[[:space:]]+~[[:space:]]*$'                  # rm -rf ~ (bare home)
  'rm[[:space:]]+-rf[[:space:]]+~[[:space:]]+(\*|--)'            # rm -rf ~ *  or  rm -rf ~ --
  'rm[[:space:]]+-rf[[:space:]]+~/\*[[:space:]]*$'               # rm -rf ~/*
  'rm[[:space:]]+-rf[[:space:]]+\$HOME[[:space:]]*$'             # rm -rf $HOME (bare)
  'rm[[:space:]]+-rf[[:space:]]+\$HOME[[:space:]]+(\*|--)'       # rm -rf $HOME *  or  --
  'rm[[:space:]]+-rf[[:space:]]+\$HOME/\*[[:space:]]*$'          # rm -rf $HOME/*
  'git reset --hard'
  'git push --force'
  'git push -f'
  'sudo '
  'curl .* \| sh'
  'curl .* \| bash'
  'wget .* \| sh'
  'wget .* \| bash'
)

for PATTERN in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$PATTERN" 2>/dev/null; then
    echo "BLOCKED: Dangerous command detected (pattern: $PATTERN)"
    echo "If you really need this, ask Molly to run it manually."
    exit 2
  fi
done

# Also block force push variants
if echo "$COMMAND" | grep -qE "git push.*--force" 2>/dev/null; then
  echo "BLOCKED: Force push detected. Use --force-with-lease if explicitly requested."
  exit 2
fi

exit 0
