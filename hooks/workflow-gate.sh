#!/bin/bash
# workflow-gate.sh — PreToolUse hook (matcher: Agent)
# Checks that workflow prerequisites are met before spawning agents.
# Specifically: if the agent prompt mentions "brief" or "spec" or "plan",
# checks that brainstorm/dialogue steps happened first.
#
# Input: JSON on stdin { "tool_name": "Agent", "tool_input": { "prompt": "...", "description": "..." } }
# Output: exit 0 = allow, exit 2 = block with feedback message on stderr
# Kill switch: WORKFLOW_GATE=off

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only gate Agent tool calls
if [ "$TOOL_NAME" != "Agent" ]; then
  exit 0
fi

# Kill switch
if [ "${WORKFLOW_GATE:-on}" = "off" ]; then
  exit 0
fi

# Shared block logger (no-op if lib missing)
source "$HOME/.claude/hooks/lib/log-block.sh" 2>/dev/null || true

PROMPT_LOWER=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
DESC_LOWER=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

# Default-allow + positive-evidence-to-block (per llm-reviewer-hooks-default-allow-on-uncertainty).
# Previously this scanned the full prompt for "product-lead|write brief" and false-positived on
# any agent prompt that mentioned the /ship pipeline (which describes product-lead writing a
# brief as a downstream stage). The fix: require the agent itself to BE a product-lead — use
# the subagent_type field or an anchored description match. Don't scan long prompts.
IS_BRIEF_REQUEST=false
if [[ "$SUBAGENT_TYPE" == *"product-lead"* || "$SUBAGENT_TYPE" == *"product_lead"* ]]; then
  IS_BRIEF_REQUEST=true
fi
# Fallback for invocations without subagent_type: description-anchored start match.
# Description is short (3-10 words); a description starting with product-lead + brief/spec is
# unambiguous. Pipeline mentions buried later in the description don't trigger.
if [ "$IS_BRIEF_REQUEST" = "false" ] && [ -z "$SUBAGENT_TYPE" ]; then
  if echo "$DESC_LOWER" | grep -qE "^(@?product.?lead)\b.*(brief|spec)" 2>/dev/null; then
    IS_BRIEF_REQUEST=true
  fi
fi

if [ "$IS_BRIEF_REQUEST" = "true" ]; then
  # Check: does the prompt mention brainstorm, questions, or dialogue happening first?
  HAS_BRAINSTORM=false
  if echo "$PROMPT_LOWER" | grep -qE "(brainstorm|ask.*question|clarif|dialogue|conversation with)" 2>/dev/null; then
    HAS_BRAINSTORM=true
  fi

  if [ "$HAS_BRAINSTORM" = "false" ]; then
    echo "⚠️  WORKFLOW GATE: You're spawning a product-lead to write a brief, but there's no mention of brainstorming or asking questions first." >&2
    echo "" >&2
    echo "The /plan workflow requires:" >&2
    echo "  1. Ask clarifying questions (ask-questions-if-underspecified)" >&2
    echo "  2. Brainstorm with the user (compound-engineering:workflows:brainstorm)" >&2
    echo "  3. THEN write the brief" >&2
    echo "" >&2
    echo "Did you have a brainstorm dialogue with the user? If yes, mention it in the agent prompt." >&2
    echo "If no, go back and do it first." >&2
    echo "" >&2
    echo "Kill switch (this session): export WORKFLOW_GATE=off" >&2
    type log_block >/dev/null 2>&1 && log_block "BLOCKED: product-lead dispatch without brainstorm evidence" "WORKFLOW_GATE"
    exit 2
  fi
fi

# Check if engineer is being asked to explore without a brief existing
IS_EXPLORE_REQUEST=false
if echo "$PROMPT_LOWER" | grep -qE "(engineer.*explor|solution.*explor|explore.*solution|research.*how.*build)" 2>/dev/null; then
  IS_EXPLORE_REQUEST=true
fi
if echo "$DESC_LOWER" | grep -qE "(engineer.*explor|explore.*solution)" 2>/dev/null; then
  IS_EXPLORE_REQUEST=true
fi

if [ "$IS_EXPLORE_REQUEST" = "true" ]; then
  # Check if any brief exists in docs/briefs/
  CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
  BRIEF_DIR="$CWD/docs/briefs"

  if [ -d "$BRIEF_DIR" ]; then
    BRIEF_COUNT=$(find "$BRIEF_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$BRIEF_COUNT" -eq 0 ]; then
      echo "⚠️  WORKFLOW GATE: You're spawning an engineer to explore solutions, but no product brief exists at docs/briefs/." >&2
      echo "" >&2
      echo "The /plan workflow requires a product brief BEFORE solution exploration." >&2
      echo "Run Phase 1 first (product-lead writes the brief)." >&2
      echo "" >&2
      echo "Kill switch (this session): export WORKFLOW_GATE=off" >&2
      type log_block >/dev/null 2>&1 && log_block "BLOCKED: engineer-explore dispatch with no brief in docs/briefs/" "WORKFLOW_GATE"
      exit 2
    fi
  fi
fi

# Check if this is a build/engineer agent that should include test instructions.
# Same default-allow + positive-evidence pattern as the brief check above: require
# subagent_type to be engineer, OR description to START with build/engineer/implement.
# Don't scan long prompts (false-positives on pipeline boilerplate that mentions
# downstream engineer dispatch).
IS_BUILD_AGENT=false
if [[ "$SUBAGENT_TYPE" == *"engineer"* ]]; then
  IS_BUILD_AGENT=true
fi
if [ "$IS_BUILD_AGENT" = "false" ] && [ -z "$SUBAGENT_TYPE" ]; then
  if echo "$DESC_LOWER" | grep -qE "^(build|engineer|implement|@engineer)\b" 2>/dev/null; then
    IS_BUILD_AGENT=true
  fi
fi
# Keep the prompt-anchored fallback for hand-written prompts that start with the
# engineer persona ("You are the engineer..."). This is a strong positive signal.
if [ "$IS_BUILD_AGENT" = "false" ]; then
  if echo "$PROMPT_LOWER" | grep -qE "^(you are the engineer|build feature|implement)" 2>/dev/null; then
    IS_BUILD_AGENT=true
  fi
fi

if [ "$IS_BUILD_AGENT" = "true" ]; then
  HAS_TEST_INSTRUCTION=false
  if echo "$PROMPT_LOWER" | grep -qE "(write test|create test|test.*(file|cover|render)|also test|include test)" 2>/dev/null; then
    HAS_TEST_INSTRUCTION=true
  fi
  # Research-only agents don't need test instructions
  if echo "$PROMPT_LOWER" | grep -qE "(research only|read.only|do not (write|edit|create)|no code change)" 2>/dev/null; then
    HAS_TEST_INSTRUCTION=true
  fi

  if [ "$HAS_TEST_INSTRUCTION" = "false" ]; then
    echo "⚠️  WORKFLOW GATE: Build agent prompt doesn't mention writing tests." >&2
    echo "" >&2
    echo "CLAUDE.md Coding Standard #9: Tests ship with features." >&2
    echo "Add test instructions to the agent prompt, e.g.:" >&2
    echo "  'Also write tests covering: renders, loading/error states, key interactions.'" >&2
    echo "" >&2
    echo "If this is a research/read-only agent, add 'research only' to the prompt." >&2
    echo "" >&2
    echo "Kill switch (this session): export WORKFLOW_GATE=off" >&2
    type log_block >/dev/null 2>&1 && log_block "BLOCKED: build/engineer agent prompt missing test instructions" "WORKFLOW_GATE"
    exit 2
  fi
fi

exit 0
