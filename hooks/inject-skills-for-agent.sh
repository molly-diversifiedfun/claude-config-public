#!/usr/bin/env bash
# inject-skills-for-agent.sh — PreToolUse:Agent hook (Phase 7.5 → 8.x.4)
#
# TWO modes, mutually exclusive:
#
# MODE 1 — Alias resolution (Phase 8.x.4): deprecated alias names get the
#   FULL agent body of the correct new agent injected via updatedInput.prompt.
#   updatedInput.subagent_type is NOT supported by the harness (crashes with
#   "undefined is not an object"); prompt injection is the only viable lever.
#   The dispatched general-purpose agent receives the new agent's complete
#   definition (role, JTBDs, skills, notes) and behaves accordingly — not as
#   clean as a real frontmatter load (no tool/skill grants) but far better
#   than running generic. Deprecation notice included so the orchestrator
#   learns the correct name for future dispatches.
#
#   Alias map: engineer→builder, content-social/longform/business→creator,
#   tech-researcher/market-researcher→researcher, project-manager→operator.
#
# MODE 2 — Skill injection (Phase 7.5 legacy): if an alias is somehow NOT
#   in the alias map (shouldn't happen), falls through to the old prefilter
#   skill-injection path. Kept as defense-in-depth; expected to be dead code.
#
# Real manifest agents (builder, creator, etc.) are NOT touched — they load
# their own .md body + frontmatter natively. See feedback_phase_7_5_hook_
# hijacks_manifest_agents for why they MUST be excluded.
#
# Kill switch: SKILL_INJECT_FOR_AGENT=off
# Log: ~/.claude/logs/inject-skills-for-agent.log

set +e

LOG="$HOME/.claude/logs/inject-skills-for-agent.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log_outcome() {
  local subagent="$1" query="$2" outcome="$3"
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"ts":"%s","subagent_type":"%s","query":"%s","outcome":"%s"}\n' \
    "$ts" "$subagent" "${query:0:80}" "$outcome" >> "$LOG" 2>/dev/null
}

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
[ "$TOOL_NAME" != "Agent" ] && exit 0

if [ "${SKILL_INJECT_FOR_AGENT:-on}" = "off" ]; then
  log_outcome "?" "" "skipped:kill_switch"
  exit 0
fi

SUBAGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

# ── MODE 1: Alias resolution ────────────────────────────────────────────
# Map deprecated name → correct manifest agent name
case "$SUBAGENT" in
  engineer)                                          TARGET=builder ;;
  content-social|content-longform|content-business)  TARGET=creator ;;
  tech-researcher|market-researcher)                 TARGET=researcher ;;
  project-manager)                                   TARGET=operator ;;
  *)                                                 TARGET="" ;;
esac

if [ -n "$TARGET" ]; then
  AGENT_FILE="$HOME/.claude/agents/${TARGET}.md"
  if [ -f "$AGENT_FILE" ]; then
    # Strip YAML frontmatter (--- ... ---) — harness can't apply those grants
    AGENT_BODY=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$AGENT_FILE")
    # Build the full prompt in a temp file so jq can safely JSON-escape it
    TMPF=$(mktemp)
    trap 'rm -f "$TMPF"' EXIT
    cat > "$TMPF" <<EOFPROMPT
<!-- DEPRECATED ALIAS: '$SUBAGENT' resolved to '$TARGET'. Use subagent_type='$TARGET' in future dispatches. -->
${AGENT_BODY}

---

${PROMPT}
EOFPROMPT
    jq -n --rawfile np "$TMPF" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:{prompt:$np}}}' 2>/dev/null
    rm -f "$TMPF" 2>/dev/null
    log_outcome "$SUBAGENT" "" "alias_body_injected:$TARGET"
    exit 0
  else
    # Agent file missing — soft-fail, let dispatch proceed as generic
    log_outcome "$SUBAGENT" "" "alias_file_missing:$TARGET"
    exit 0
  fi
fi

# ── Non-alias, non-manifest agents: skip ─────────────────────────────────
# Real manifest agents are NOT in the alias map, so they reach here and exit.
# This is correct — they load natively and must NOT receive updatedInput.prompt.
log_outcome "$SUBAGENT" "" "skipped:not_alias"
exit 0
