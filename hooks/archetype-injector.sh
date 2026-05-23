#!/usr/bin/env bash
# archetype-injector.sh — UserPromptSubmit hook (Phase 6.2)
# Reads cwd from stdin JSON, resolves archetype, emits additionalContext block
# listing relevant learned/ patterns + always-on (severity=blocking) patterns.
#
# Kill switch: ARCHETYPE_GATE=off → exit 0 with {} (no-op).
# Fail-open: any error → exit 0 with {} (never block harness).

set +e

MANIFEST="$HOME/.claude/projects.yaml"
SKILL_MANIFEST="$HOME/.claude/skill-archetypes.yaml"
WORK_TYPE_CHAINS="$HOME/.claude/work-type-chains.yaml"
LEARNED_DIR="$HOME/.claude/skills/learned"
PERSONAL_SKILLS_DIR="$HOME/.claude/skills"
PLUGIN_CACHE_DIR="$HOME/.claude/plugins/cache"
CACHE_FILE="$HOME/.claude/checkpoints/archetype-cache.json"
LOG_FILE="$HOME/.claude/logs/archetype-injection.log"

emit_noop() { echo '{}'; exit 0; }
emit_ctx()  { jq -n --arg ctx "$1" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'; exit 0; }

# Phase 7.1.5.1: finalize CTX by inserting work-type block at emit time.
# Caller provides BASE_CTX (cacheable, prompt-independent). This function injects
# the 🧭 block before the 🛠 (or Always-on) section if WORK_TYPE_BLOCK is set.
# Decoupling work-type from the cached CTX prevents prompt-N from poisoning prompt-N+1
# on the same cwd.
finalize_ctx() {
  local base="$1"
  if [ -z "$WORK_TYPE_BLOCK" ]; then
    printf '%s' "$base"
    return
  fi
  # awk -v can't carry newlines; ENVIRON does. The env var must be set on awk
  # (the receiving end of the pipe), not on printf.
  printf '%s' "$base" | WT_BLOCK_ENV="$WORK_TYPE_BLOCK" awk '
    /^🛠 Likely-useful/ && !inserted { print ENVIRON["WT_BLOCK_ENV"]; print ""; inserted=1 }
    /^Always-on \(severity=blocking\)/ && !inserted { print ENVIRON["WT_BLOCK_ENV"]; print ""; inserted=1 }
    { print }
  '
}

if [ "${ARCHETYPE_GATE:-on}" = "off" ]; then
  emit_noop
fi

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && emit_noop

CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$CWD" ] && emit_noop

# Phase 7.1.5: read prompt for work-type detection (prompt is optional; absence = no 🧭 block)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# === Phase 7.1.5.1: work-type detection runs BEFORE cache check ===
# (detection is prompt-dependent; cache is cwd-keyed; decoupling prevents pollution)
WORK_TYPE=""
WORK_TYPE_CHAIN_LIST=""
WORK_TYPE_BLOCK=""
if [ "${WORKTYPE_GATE:-on}" != "off" ] && [ -n "$PROMPT" ] && [ -f "$WORK_TYPE_CHAINS" ]; then
  WORK_TYPE_ORDER="plan build debug review research write-content memory design infra"
  PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
  for wt in $WORK_TYPE_ORDER; do
    case "$wt" in
      plan)          PAT='\b(brainstorm|let.?s think|plan this|spec|design (the|a|this)|scope this|propose approach|break.?down|sequence)\b' ;;
      build)         PAT='\b(implement|build|ship|create new|add (a|the) (feature|endpoint|component)|let.?s code|wire up)\b' ;;
      debug)         PAT='\b(debug|investigate|trace|why (is|does|did)|broken|failing|error|stack trace|bug|crash)\b' ;;
      review)        PAT='\b(review|audit|critique|red.?team|check (the )?code|sanity check)\b' ;;
      research)      PAT='\b(research|look up|find (the )?docs|how does .* work|what.?s the api|recipe for)\b' ;;
      write-content) PAT='\b(write a (post|caption|email|carousel|essay|tweet|thread|reel|video)|copy for|content for|caption|tagline|hook for|draft (a )?(post|email))\b' ;;
      memory)        PAT='\b(handoff|capture (this|that)|remember|recall|save (the )?context|update memory|/promote|/learn|synthesize)\b' ;;
      design)        PAT='\b(design (a|the) (ui|hero|landing|page)|mockup|wireframe|tsx component|tailwind|figma)\b' ;;
      infra)         PAT='\b(hook|settings\.json|carl|plugin|mcp server|env var|configure|automation|skill-archetypes)\b' ;;
    esac
    if echo "$PROMPT_LOWER" | grep -qE "$PAT"; then
      WORK_TYPE="$wt"
      break
    fi
  done

  if [ -n "$WORK_TYPE" ]; then
    CHAIN_RAW=$(awk -v wt="$WORK_TYPE" '
      $0 == wt ":" { in_block=1; next }
      in_block && /^[a-z][a-z-]+:$/ { in_block=0 }
      in_block && /^  - / { sub(/^  - /, ""); print }
    ' "$WORK_TYPE_CHAINS")

    if [ -n "$CHAIN_RAW" ]; then
      IDX=1
      while IFS= read -r sname; do
        [ -z "$sname" ] && continue
        TAGLINE=""
        SKILL_FILE=""
        if [ "${sname#*:}" = "$sname" ]; then
          if [ "${sname:0:1}" = "/" ]; then
            TAGLINE=""
          else
            SKILL_FILE="$PERSONAL_SKILLS_DIR/$sname/SKILL.md"
          fi
        else
          PLUGIN_PREFIX="${sname%%:*}"
          SKILL_BASE="${sname#*:}"
          SKILL_FILE=$(find "$PLUGIN_CACHE_DIR"/*/"$PLUGIN_PREFIX" -path "*/skills/$SKILL_BASE/SKILL.md" 2>/dev/null | head -1)
        fi
        if [ -n "$SKILL_FILE" ] && [ -f "$SKILL_FILE" ]; then
          TAGLINE=$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit}' "$SKILL_FILE" 2>/dev/null | cut -c1-60)
        fi
        if [ -n "$TAGLINE" ]; then
          WORK_TYPE_CHAIN_LIST="$WORK_TYPE_CHAIN_LIST
  $IDX. $sname — $TAGLINE"
        else
          WORK_TYPE_CHAIN_LIST="$WORK_TYPE_CHAIN_LIST
  $IDX. $sname"
        fi
        IDX=$((IDX + 1))
      done <<< "$CHAIN_RAW"

      # Build the standalone WORK_TYPE_BLOCK once — finalize_ctx() inserts it.
      WORK_TYPE_BLOCK="🧭 Work-type detected: $WORK_TYPE
Suggested skill chain (in order):$WORK_TYPE_CHAIN_LIST"
    else
      mkdir -p "$(dirname "$LOG_FILE")"
      echo "$(date -u +%FT%TZ) work-type=$WORK_TYPE has no chain in $WORK_TYPE_CHAINS" >> "$LOG_FILE"
      WORK_TYPE=""
    fi
  fi
fi
# === end Phase 7.1.5.1 ===

# Cache: skip recompute if cwd was seen and manifest/learned haven't changed.
mkdir -p "$(dirname "$CACHE_FILE")"

# Compute freshness key from manifest + learned dir mtimes.
FRESH_KEY="0"
if [ -f "$MANIFEST" ]; then
  FRESH_KEY="$(stat -f %m "$MANIFEST" 2>/dev/null || stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)"
fi
if [ -d "$LEARNED_DIR" ]; then
  LEARN_MTIME="$(stat -f %m "$LEARNED_DIR" 2>/dev/null || stat -c %Y "$LEARNED_DIR" 2>/dev/null || echo 0)"
  FRESH_KEY="${FRESH_KEY}-${LEARN_MTIME}"
fi
if [ -f "$SKILL_MANIFEST" ]; then
  SKILL_MTIME="$(stat -f %m "$SKILL_MANIFEST" 2>/dev/null || stat -c %Y "$SKILL_MANIFEST" 2>/dev/null || echo 0)"
  FRESH_KEY="${FRESH_KEY}-${SKILL_MTIME}"
fi

# Try cache.
if [ -f "$CACHE_FILE" ]; then
  CACHED_KEY=$(jq -r --arg cwd "$CWD" '.[$cwd].freshKey // ""' "$CACHE_FILE" 2>/dev/null)
  if [ "$CACHED_KEY" = "$FRESH_KEY" ]; then
    CACHED_CTX=$(jq -r --arg cwd "$CWD" '.[$cwd].context // ""' "$CACHE_FILE" 2>/dev/null)
    if [ -n "$CACHED_CTX" ]; then
      # Phase 7.1.5.1: cached CTX is base only; insert fresh work-type at emit.
      emit_ctx "$(finalize_ctx "$CACHED_CTX")"
    fi
  fi
fi

ARCHETYPE=""

if [ -f "$MANIFEST" ]; then
  CWD_NORM=$(echo "$CWD" | sed "s|^$HOME|~|")
  ARCHETYPE=$(grep -E "^\"$CWD_NORM\":" "$MANIFEST" 2>/dev/null | head -1 | sed -E 's/^"[^"]+":[[:space:]]*//' | tr -d ' "')

  if [ -z "$ARCHETYPE" ]; then
    BEST_LEN=0
    while IFS= read -r line; do
      PREFIX=$(echo "$line" | sed -E 's/^"([^"]+)":.*/\1/')
      LEN=${#PREFIX}
      PREFIX_EXPANDED="${PREFIX/#~/$HOME}"
      case "$CWD" in
        "$PREFIX_EXPANDED"/*|"$PREFIX_EXPANDED")
          if [ "$LEN" -gt "$BEST_LEN" ]; then
            BEST_LEN=$LEN
            ARCHETYPE=$(echo "$line" | sed -E 's/^"[^"]+":[[:space:]]*//' | tr -d ' "')
          fi
          ;;
      esac
    done < <(grep -E '^"[^"]+":' "$MANIFEST" 2>/dev/null)
  fi
fi

if [ -z "$ARCHETYPE" ]; then
  if [ -f "$CWD/package.json" ] && { [ -f "$CWD/vite.config.ts" ] || [ -f "$CWD/vite.config.js" ]; }; then
    ARCHETYPE="web-app"
  elif [ -f "$CWD/pyproject.toml" ] || [ -f "$CWD/requirements.txt" ]; then
    ARCHETYPE="python-cli"
  elif [ -d "$CWD/n8n" ]; then
    ARCHETYPE="telegram-bot"
  else
    ARCHETYPE="unknown"
  fi
fi

mkdir -p "$(dirname "$LOG_FILE")"
echo "$(date -u +%FT%TZ) cwd=$CWD archetype=$ARCHETYPE" >> "$LOG_FILE"

RELEVANT_NAMES=""
BLOCKING_NAMES=""

for f in "$LEARNED_DIR"/*.md; do
  [ "$(basename "$f")" = "SKILL.md" ] && continue
  [ -f "$f" ] || continue

  NAME=$(basename "$f" .md)

  FM=$(awk '/^---[[:space:]]*$/ { if(s==0){s=1;next}; if(s==1){exit} } s==1 {print}' "$f" 2>/dev/null)

  SEV=$(echo "$FM" | awk '/^severity:/ {sub(/^severity:[[:space:]]*/, ""); print; exit} /^  severity:/ {sub(/^  severity:[[:space:]]*/, ""); print; exit}' | tr -d '"'"'")
  ARCHS=$(echo "$FM" | awk '/^archetypes:/ {sub(/^archetypes:[[:space:]]*/, ""); print; exit} /^  archetypes:/ {sub(/^  archetypes:[[:space:]]*/, ""); print; exit}')

  if [ "$SEV" = "blocking" ]; then
    BLOCKING_NAMES="$BLOCKING_NAMES $NAME"
    continue
  fi

  ARCH_ESCAPED=$(printf '%s' "$ARCHETYPE" | sed 's/[][\\.*+?(){}|^$]/\\&/g')
  if [ -n "$ARCHS" ] && echo "$ARCHS" | grep -qE "(^|[,[ ])($ARCH_ESCAPED|always-on)([],[:space:]]|$)"; then
    RELEVANT_NAMES="$RELEVANT_NAMES $NAME"
    continue
  fi

  if [ -z "$ARCHS" ]; then
    RELEVANT_NAMES="$RELEVANT_NAMES $NAME"
  fi
done

CWD_DISPLAY=$(echo "$CWD" | sed "s|^$HOME|~|")
RELEVANT_LIST=$(echo "$RELEVANT_NAMES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /')
BLOCKING_LIST=$(echo "$BLOCKING_NAMES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /')

# === Phase 7.1: skill archetype injection ===
SKILL_NAMES=""
SKILL_LIST=""
if [ "${SKILL_INJECTION:-on}" != "off" ] && [ -f "$SKILL_MANIFEST" ]; then
  ARCH_ESCAPED=$(printf '%s' "$ARCHETYPE" | sed 's/[][\\.*+?(){}|^$]/\\&/g')
  while IFS= read -r line; do
    case "$line" in ""|\#*) continue ;; esac
    SNAME=$(echo "$line" | sed -E 's/^"([^"]+)":.*/\1/')
    SARCHS=$(echo "$line" | sed -E 's/^"[^"]+":[[:space:]]*\[([^][]+)\].*/\1/')
    if echo "$SARCHS" | grep -qE "(^|[, ])($ARCH_ESCAPED|always-on)([,[:space:]]|$)"; then
      SKILL_NAMES="$SKILL_NAMES $SNAME"
    fi
  done < "$SKILL_MANIFEST"

  # Sort alphabetical + cap at 10
  SKILL_NAMES_SORTED=$(echo "$SKILL_NAMES" | tr ' ' '\n' | grep -v '^$' | sort -u | head -10)

  # Build the rendered list with taglines from each skill's SKILL.md description.
  while IFS= read -r sname; do
    [ -z "$sname" ] && continue
    TAGLINE=""
    SKILL_FILE=""
    if [ "${sname#*:}" = "$sname" ]; then
      # Personal skill (no plugin prefix)
      SKILL_FILE="$PERSONAL_SKILLS_DIR/$sname/SKILL.md"
    else
      # Plugin skill — look up across marketplaces (cache layout: <marketplace>/<plugin>/<ver>/skills/<skill>/SKILL.md)
      PLUGIN_PREFIX="${sname%%:*}"
      SKILL_BASE="${sname#*:}"
      SKILL_FILE=$(find "$PLUGIN_CACHE_DIR"/*/"$PLUGIN_PREFIX" -path "*/skills/$SKILL_BASE/SKILL.md" 2>/dev/null | head -1)
    fi
    if [ -n "$SKILL_FILE" ] && [ -f "$SKILL_FILE" ]; then
      TAGLINE=$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit}' "$SKILL_FILE" 2>/dev/null | cut -c1-60)
    fi
    if [ -n "$TAGLINE" ]; then
      SKILL_LIST="$SKILL_LIST
  - $sname — $TAGLINE"
    else
      SKILL_LIST="$SKILL_LIST
  - $sname"
    fi
  done <<< "$SKILL_NAMES_SORTED"
fi

# Build BASE_CTX — prompt-independent, cacheable. Work-type 🧭 block is inserted
# at emit time by finalize_ctx() so the cache stays valid across prompts.
if [ -n "$SKILL_LIST" ]; then
  BASE_CTX="🎯 Archetype: $ARCHETYPE (cwd: $CWD_DISPLAY)

Relevant learned/ patterns this session:
$RELEVANT_LIST

🛠 Likely-useful skills for this archetype:$SKILL_LIST

Always-on (severity=blocking) — apply regardless of project:
$BLOCKING_LIST

Kill switches: ARCHETYPE_GATE=off | SKILL_INJECTION=off | WORKTYPE_GATE=off (export to disable)."
else
  BASE_CTX="🎯 Archetype: $ARCHETYPE (cwd: $CWD_DISPLAY)

Relevant learned/ patterns this session:
$RELEVANT_LIST

Always-on (severity=blocking) — apply regardless of project:
$BLOCKING_LIST

Kill switches: ARCHETYPE_GATE=off | SKILL_INJECTION=off | WORKTYPE_GATE=off (export to disable)."
fi

# Write cache before emitting. Cache stores BASE_CTX only (work-type bypasses cache).
if [ -f "$CACHE_FILE" ]; then
  TMP_CACHE=$(mktemp)
  jq --arg cwd "$CWD" --arg arch "$ARCHETYPE" --arg ctx "$BASE_CTX" --arg fk "$FRESH_KEY" \
    '.[$cwd] = {archetype: $arch, context: $ctx, freshKey: $fk}' \
    "$CACHE_FILE" > "$TMP_CACHE" 2>/dev/null && mv "$TMP_CACHE" "$CACHE_FILE" || rm -f "$TMP_CACHE"
else
  jq -n --arg cwd "$CWD" --arg arch "$ARCHETYPE" --arg ctx "$BASE_CTX" --arg fk "$FRESH_KEY" \
    '{($cwd): {archetype: $arch, context: $ctx, freshKey: $fk}}' > "$CACHE_FILE"
fi

emit_ctx "$(finalize_ctx "$BASE_CTX")"
