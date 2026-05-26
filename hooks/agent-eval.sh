#!/usr/bin/env bash
# agent-eval.sh — Phase 7.6 dual-mode hook
#   --enqueue: PostToolUse:Agent hook, snapshots (task, injected_skills, agent_return) to queue dir
#   --drain:   Stop hook, drains queue via claude -p --model haiku, appends judgments to JSONL
#
# Soft-fails open on every internal error — never blocks the user's session.
#
# Kill switches:
#   AGENT_EVAL=off         disables both modes
#   AGENT_EVAL_DRAIN=off   enqueue still runs; drain skipped
#
# Env-var overrides (for tests):
#   AGENT_EVAL_QUEUE_DIR   default: ~/.claude/data/agent-eval-queue
#   AGENT_EVAL_LOG_FILE    default: ~/.claude/logs/agent-eval.log
#   AGENT_EVAL_JSONL       default: ~/.claude/data/agent-eval.jsonl
#
# Spec: ~/github/docs/superpowers/specs/2026-05-21-phase-7-6-llm-judge-evaluator-design.md

set +e

MODE="${1:-}"
QUEUE_DIR="${AGENT_EVAL_QUEUE_DIR:-$HOME/.claude/data/agent-eval-queue}"
LOG_FILE="${AGENT_EVAL_LOG_FILE:-$HOME/.claude/logs/agent-eval.log}"
JSONL="${AGENT_EVAL_JSONL:-$HOME/.claude/data/agent-eval.jsonl}"
JUDGE_MODEL="${AGENT_EVAL_MODEL:-claude-haiku-4-5-20251001}"
JUDGE_TIMEOUT_S="${AGENT_EVAL_TIMEOUT_S:-30}"
DRAIN_MAX_FILES="${AGENT_EVAL_MAX_FILES:-20}"

mkdir -p "$(dirname "$LOG_FILE")" "$QUEUE_DIR" "$QUEUE_DIR/.failed" "$(dirname "$JSONL")" 2>/dev/null

log_outcome() {
  local mode="$1"
  local subagent="$2"
  local outcome="$3"
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"ts":"%s","mode":"%s","subagent_type":"%s","outcome":"%s"}\n' \
    "$ts" "$mode" "$subagent" "$outcome" >> "$LOG_FILE" 2>/dev/null
}

build_judge_prompt() {
  # Args: $1 = task, $2 = injected_skills (JSON array as string), $3 = agent_return
  local task="$1"
  local skills_json="$2"
  local agent_return="$3"
  local skills_md
  skills_md=$(echo "$skills_json" | jq -r 'to_entries | map("\(.key+1). \(.value)") | join("\n")')

  cat <<EOF
You evaluate whether a subagent used helpful skills for its task.

You will be given:
- TASK: what the subagent was asked to do
- INJECTED_SKILLS: 3 skills suggested by a prefilter at dispatch time
- AGENT_RETURN: what the subagent produced

Output STRICT JSON only, no prose, no markdown fences. Schema:

{
  "used_injected_skill": <bool>,
  "which_skill": <string|null>,
  "better_skill_suggested": <string|null>,
  "quality_score": <int 1-5>,
  "rationale": <string, max 200 chars>
}

Hard rules:
- "used_injected_skill" is true ONLY if AGENT_RETURN contains evidence the skill's approach shaped the output. Mere mention does not count.
- "which_skill" must be one of the INJECTED_SKILLS strings (exact match) when used_injected_skill is true; otherwise null.
- "better_skill_suggested" is null unless you can name a specific skill string from the user's installed catalog with high confidence. Hallucinated skill names are forbidden.
- "quality_score": 1=missed task, 2=partial off-target, 3=adequate, 4=clearly delivered, 5=exemplary.
- Never output anything outside the JSON object.

---

TASK:
${task}

INJECTED_SKILLS:
${skills_md}

AGENT_RETURN:
${agent_return}
EOF
}

run_judge() {
  # Args: $1 = prompt file path. Echoes response on stdout. Exit code passes through.
  # `timeout` is not present on stock macOS; prefer GNU coreutils variants if available,
  # otherwise run claude directly (the test stub returns instantly; prod degrades to no timeout).
  local prompt_file="$1"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$JUDGE_TIMEOUT_S" claude -p --model "$JUDGE_MODEL" --output-format text < "$prompt_file" 2>/dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$JUDGE_TIMEOUT_S" claude -p --model "$JUDGE_MODEL" --output-format text < "$prompt_file" 2>/dev/null
  else
    claude -p --model "$JUDGE_MODEL" --output-format text < "$prompt_file" 2>/dev/null
  fi
}

validate_judge_response() {
  # Args: $1 = response string. Exit 0 if valid JSON with required fields, else 1.
  echo "$1" | jq -e 'type=="object" and has("used_injected_skill") and has("quality_score") and has("which_skill") and has("better_skill_suggested") and has("rationale")' >/dev/null 2>&1
}

process_queue_file() {
  # Args: $1 = path to snapshot JSON. Returns 0 on success (row appended), 1 on giving up.
  local snap="$1"
  local task; task=$(jq -r '.task' "$snap")
  local skills_json; skills_json=$(jq -c '.injected_skills' "$snap")
  local agent_return; agent_return=$(jq -r '.agent_return' "$snap")
  local original_ts; original_ts=$(jq -r '.ts' "$snap")
  local subagent; subagent=$(jq -r '.subagent_type' "$snap")

  local prompt_file; prompt_file=$(mktemp)
  build_judge_prompt "$task" "$skills_json" "$agent_return" > "$prompt_file"

  local response; response=$(run_judge "$prompt_file")

  # Retry once on bad JSON
  if ! validate_judge_response "$response"; then
    {
      cat "$prompt_file"
      echo ""
      echo "Your previous response was not valid JSON. Reply with JSON only, no fences."
    } > "${prompt_file}.retry"
    response=$(run_judge "${prompt_file}.retry")
    rm -f "${prompt_file}.retry"

    if ! validate_judge_response "$response"; then
      rm -f "$prompt_file"
      mv "$snap" "$QUEUE_DIR/.failed/$(basename "$snap")" 2>/dev/null
      log_outcome "drain" "$subagent" "error:parse_failed_2x"
      return 1
    fi
  fi

  rm -f "$prompt_file"

  # Build eval record
  local drain_ts; drain_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local task_excerpt; task_excerpt="${task:0:200}"
  local row
  row=$(jq -n -c \
    --arg ts "$original_ts" \
    --arg drain_ts "$drain_ts" \
    --arg subagent "$subagent" \
    --arg task_excerpt "$task_excerpt" \
    --argjson skills "$skills_json" \
    --argjson judgment "$response" \
    --arg model "$JUDGE_MODEL" \
    '{ts:$ts,drain_ts:$drain_ts,subagent_type:$subagent,task_excerpt:$task_excerpt,injected_skills:$skills,judgment:$judgment,judge_model:$model}')

  echo "$row" >> "$JSONL"
  rm -f "$snap"
  local score; score=$(echo "$response" | jq -r '.quality_score')
  log_outcome "drain" "$subagent" "judged:score_$score"
  return 0
}

enqueue() {
  if [ "${AGENT_EVAL:-on}" = "off" ]; then
    log_outcome "enqueue" "?" "skipped:kill_switch"
    return 0
  fi

  local input; input=$(cat 2>/dev/null)
  if [ -z "$input" ]; then
    log_outcome "enqueue" "?" "skipped:bad_input"
    return 0
  fi

  local tool_name; tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
  if [ "$tool_name" != "Agent" ]; then
    return 0
  fi

  local subagent; subagent=$(echo "$input" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)

  # Phase 8.x.4: allowlist = all 12 manifest agents + 7 deprecated aliases
  case "$subagent" in
    builder|creator|strategist|researcher|operator|product-lead|designer|debugger|security|reviewer|content-qa|memory-keeper)
      ;;
    engineer|content-social|content-longform|content-business|tech-researcher|market-researcher|project-manager)
      ;;
    *)
      log_outcome "enqueue" "$subagent" "skipped:not_allowlisted"
      return 0
      ;;
  esac

  local prompt; prompt=$(echo "$input" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

  # Phase 8.x.4: detect alias body-injection marker OR fire for manifest agents directly
  local skills_json="[]"
  local task="$prompt"
  if echo "$prompt" | grep -q '<!-- DEPRECATED ALIAS:'; then
    # Alias dispatch — extract target agent name from the marker
    local target; target=$(echo "$prompt" | grep -oE "resolved to '[a-z-]+'" | head -1 | sed "s/resolved to '//;s/'//")
    if [ -n "$target" ]; then
      skills_json=$(jq -n -c --arg t "$target" '["alias-body-injection:\($t)"]')
    fi
    # Strip the injected body to get the original task (after the --- separator)
    task=$(echo "$prompt" | awk '/^---$/{found++} found>=1 && found<2{next} found>=2{print}' | sed -e '/./,$!d')
  elif echo "$prompt" | grep -q '<!-- phase-7-5-injected-skills v1 -->'; then
    # Legacy Phase 7.5 marker (backward compat for old-format dispatches still in context)
    skills_json=$(echo "$prompt" | awk '
      /<!-- phase-7-5-injected-skills v1 -->/ { in_block=1; next }
      /<!-- \/phase-7-5-injected-skills -->/  { in_block=0; next }
      in_block && /^- / { print }
    ' | awk -F' — ' '{ sub(/^- /, "", $1); print $1 }' | jq -R -s -c 'split("\n") | map(select(length>0))')
    task=$(echo "$prompt" | awk '
      /<!-- phase-7-5-injected-skills v1 -->/ { stripping=1; next }
      /<!-- \/phase-7-5-injected-skills -->/  { stripping=0; next }
      !stripping { print }
    ' | sed -e '/./,$!d')
  fi
  # For direct manifest agent dispatches (no marker), task=$prompt and skills_json=[] — both already set

  # agent_return: tool_response.content can be string or array of content blocks
  local agent_return
  agent_return=$(echo "$input" | jq -r '
    if (.tool_response.content | type) == "string" then .tool_response.content
    elif (.tool_response.content | type) == "array" then ([.tool_response.content[] | select(.type=="text") | .text] | join("\n"))
    else "" end
  ' 2>/dev/null)

  # Atomic write: tmp file in queue dir, then mv into place
  local ts; ts=$(date -u +%Y-%m-%dT%H-%M-%SZ)
  local uuid; uuid=$(jot -r 1 100000 999999 2>/dev/null || echo $$)
  local snap_tmp; snap_tmp=$(mktemp "$QUEUE_DIR/.snap.XXXXXX")
  local snap_final="$QUEUE_DIR/${ts}-${uuid}.json"

  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg subagent "$subagent" \
    --arg task "$task" \
    --argjson skills "$skills_json" \
    --arg agent_return "$agent_return" \
    '{ts:$ts,subagent_type:$subagent,task:$task,injected_skills:$skills,agent_return:$agent_return}' \
    > "$snap_tmp" 2>/dev/null

  if [ ! -s "$snap_tmp" ]; then
    rm -f "$snap_tmp"
    log_outcome "enqueue" "$subagent" "error:jq_build_failed"
    return 0
  fi

  mv "$snap_tmp" "$snap_final" 2>/dev/null
  if [ -f "$snap_final" ]; then
    log_outcome "enqueue" "$subagent" "enqueued"
  else
    log_outcome "enqueue" "$subagent" "error:mv_failed"
  fi

  return 0
}

drain() {
  if [ "${AGENT_EVAL:-on}" = "off" ]; then
    log_outcome "drain" "-" "skipped:kill_switch"
    return 0
  fi
  if [ "${AGENT_EVAL_DRAIN:-on}" = "off" ]; then
    log_outcome "drain" "-" "skipped:drain_kill"
    return 0
  fi

  # mkdir-based lock: only one drain runs at a time (POSIX-portable, no flock needed)
  local lockdir="$QUEUE_DIR/.drain-lock"
  if ! mkdir "$lockdir" 2>/dev/null; then
    # Check for stale lock (older than 5 min = 300s)
    local lock_age=0
    if [ -f "$lockdir/pid" ]; then
      local lock_ts; lock_ts=$(stat -f %m "$lockdir/pid" 2>/dev/null || echo 0)
      local now_ts; now_ts=$(date +%s)
      lock_age=$(( now_ts - lock_ts ))
    fi
    if [ "$lock_age" -gt 300 ]; then
      rm -rf "$lockdir" 2>/dev/null
      mkdir "$lockdir" 2>/dev/null || { log_outcome "drain" "-" "skipped:lock_contention"; return 0; }
    else
      log_outcome "drain" "-" "skipped:already_draining"
      return 0
    fi
  fi
  echo $$ > "$lockdir/pid" 2>/dev/null

  # Ensure lock is released on exit
  trap 'rm -rf "$lockdir" 2>/dev/null' RETURN

  local count
  count=$(find "$QUEUE_DIR" -maxdepth 1 -name '*.json' -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" = "0" ]; then
    log_outcome "drain" "-" "drain:empty"
    return 0
  fi

  if ! command -v claude >/dev/null 2>&1; then
    log_outcome "drain" "-" "error:claude_p_missing"
    return 0
  fi

  local processed=0
  local start_ts; start_ts=$(date +%s)
  local file
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    [ "$processed" -ge "$DRAIN_MAX_FILES" ] && break
    local elapsed=$(( $(date +%s) - start_ts ))
    [ "$elapsed" -ge 300 ] && break

    process_queue_file "$file"
    processed=$((processed+1))
  done < <(find "$QUEUE_DIR" -maxdepth 1 -name '*.json' -type f 2>/dev/null | sort)

  log_outcome "drain" "-" "drain:done:$processed"
  return 0
}

case "$MODE" in
  --enqueue) enqueue ;;
  --drain)   drain ;;
  *)         echo "usage: $0 --enqueue|--drain" >&2; exit 0 ;;
esac

exit 0
