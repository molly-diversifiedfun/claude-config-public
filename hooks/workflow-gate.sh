#!/bin/bash
# workflow-gate.sh — PreToolUse hook (matcher: Agent)
# Checks that workflow prerequisites are met before spawning agents.
# Specifically: if the agent prompt mentions "brief" or "spec" or "plan",
# checks that brainstorm/dialogue steps happened first.
#
# Input: JSON on stdin { "tool_name": "Agent", "tool_input": { "prompt": "...", "description": "..." } }
# Output: exit 0 = allow, exit 2 = block with feedback message

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only gate Agent tool calls
if [ "$TOOL_NAME" != "Agent" ]; then
  exit 0
fi

PROMPT_LOWER=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
DESC_LOWER=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

# Check if this is a product-lead agent being asked to write a brief or spec
IS_BRIEF_REQUEST=false
if echo "$PROMPT_LOWER" | grep -qE "(product.?lead|product brief|write.*brief|writes.*brief)" 2>/dev/null; then
  IS_BRIEF_REQUEST=true
fi
if echo "$DESC_LOWER" | grep -qE "(product.?lead.*brief|writes.*brief)" 2>/dev/null; then
  IS_BRIEF_REQUEST=true
fi

if [ "$IS_BRIEF_REQUEST" = "true" ]; then
  # Check: does the prompt mention brainstorm, questions, or dialogue happening first?
  HAS_BRAINSTORM=false
  if echo "$PROMPT_LOWER" | grep -qE "(brainstorm|ask.*question|clarif|dialogue|conversation with)" 2>/dev/null; then
    HAS_BRAINSTORM=true
  fi

  if [ "$HAS_BRAINSTORM" = "false" ]; then
    echo "⚠️  WORKFLOW GATE: You're spawning a product-lead to write a brief, but there's no mention of brainstorming or asking questions first."
    echo ""
    echo "The /plan workflow requires:"
    echo "  1. Ask clarifying questions (ask-questions-if-underspecified)"
    echo "  2. Brainstorm with the user (compound-engineering:workflows:brainstorm)"
    echo "  3. THEN write the brief"
    echo ""
    echo "Did you have a brainstorm dialogue with the user? If yes, mention it in the agent prompt."
    echo "If no, go back and do it first."
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
      echo "⚠️  WORKFLOW GATE: You're spawning an engineer to explore solutions, but no product brief exists at docs/briefs/."
      echo ""
      echo "The /plan workflow requires a product brief BEFORE solution exploration."
      echo "Run Phase 1 first (product-lead writes the brief)."
      exit 2
    fi
  fi
fi

# Check if this is a build/engineer agent that should include test instructions
IS_BUILD_AGENT=false
if echo "$DESC_LOWER" | grep -qE "(build|engineer|implement)" 2>/dev/null; then
  IS_BUILD_AGENT=true
fi
if echo "$PROMPT_LOWER" | grep -qE "^(you are the engineer|build feature|implement)" 2>/dev/null; then
  IS_BUILD_AGENT=true
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
    echo "⚠️  WORKFLOW GATE: Build agent prompt doesn't mention writing tests."
    echo ""
    echo "CLAUDE.md Coding Standard #9: Tests ship with features."
    echo "Add test instructions to the agent prompt, e.g.:"
    echo "  'Also write tests covering: renders, loading/error states, key interactions.'"
    echo ""
    echo "If this is a research/read-only agent, add 'research only' to the prompt."
    exit 2
  fi
fi

exit 0
