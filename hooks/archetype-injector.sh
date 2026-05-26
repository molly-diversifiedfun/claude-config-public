#!/usr/bin/env bash
# archetype-injector.sh — UserPromptSubmit hook (simplified 2026-05-26)
# Resolves project archetype from cwd, injects relevant learned patterns.
# Skill suggestions and work-type chains moved to PreToolUse:Agent dispatch.
#
# Kill switch: ARCHETYPE_GATE=off → exit 0 with {} (no-op).
# Fail-open: any error → exit 0 with {} (never block harness).

set +e

MANIFEST="$HOME/.claude/projects.yaml"
LEARNED_DIR="$HOME/.claude/skills/learned"
CACHE_FILE="$HOME/.claude/checkpoints/archetype-cache.json"
LOG_FILE="$HOME/.claude/logs/archetype-injection.log"

emit_noop() { echo '{}'; exit 0; }
emit_ctx()  { jq -n --arg ctx "$1" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'; exit 0; }

if [ "${ARCHETYPE_GATE:-on}" = "off" ]; then
  emit_noop
fi

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && emit_noop

CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$CWD" ] && emit_noop

# === Cache check ===
mkdir -p "$(dirname "$CACHE_FILE")"

FRESH_KEY="0"
if [ -f "$MANIFEST" ]; then
  FRESH_KEY="$(stat -f %m "$MANIFEST" 2>/dev/null || stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)"
fi
if [ -d "$LEARNED_DIR" ]; then
  LEARN_MTIME="$(stat -f %m "$LEARNED_DIR" 2>/dev/null || stat -c %Y "$LEARNED_DIR" 2>/dev/null || echo 0)"
  FRESH_KEY="${FRESH_KEY}-${LEARN_MTIME}"
fi

if [ -f "$CACHE_FILE" ]; then
  CACHED_KEY=$(jq -r --arg cwd "$CWD" '.[$cwd].freshKey // ""' "$CACHE_FILE" 2>/dev/null)
  if [ "$CACHED_KEY" = "$FRESH_KEY" ]; then
    CACHED_CTX=$(jq -r --arg cwd "$CWD" '.[$cwd].context // ""' "$CACHE_FILE" 2>/dev/null)
    if [ -n "$CACHED_CTX" ]; then
      emit_ctx "$CACHED_CTX"
    fi
  fi
fi

# === Archetype resolution ===
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

# === Learned pattern filtering ===
RELEVANT_NAMES=""
BLOCKING_NAMES=""

for f in "$LEARNED_DIR"/*.md; do
  [ "$(basename "$f")" = "SKILL.md" ] && continue
  [ -f "$f" ] || continue

  NAME=$(basename "$f" .md)
  FM=$(awk '/^---[[:space:]]*$/ { if(s==0){s=1;next}; if(s==1){exit} } s==1 {print}' "$f" 2>/dev/null)

  SEV=$(echo "$FM" | awk '/^severity:/ {sub(/^severity:[[:space:]]*/, ""); print; exit}' | tr -d '"'"'")
  ARCHS=$(echo "$FM" | awk '/^archetypes:/ {sub(/^archetypes:[[:space:]]*/, ""); print; exit}')

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

BASE_CTX="🎯 Archetype: $ARCHETYPE (cwd: $CWD_DISPLAY)

Relevant learned/ patterns this session:
$RELEVANT_LIST

Always-on (severity=blocking) — apply regardless of project:
$BLOCKING_LIST

Kill switches: ARCHETYPE_GATE=off (export to disable)."

# === Cache + emit ===
if [ -f "$CACHE_FILE" ]; then
  TMP_CACHE=$(mktemp)
  jq --arg cwd "$CWD" --arg arch "$ARCHETYPE" --arg ctx "$BASE_CTX" --arg fk "$FRESH_KEY" \
    '.[$cwd] = {archetype: $arch, context: $ctx, freshKey: $fk}' \
    "$CACHE_FILE" > "$TMP_CACHE" 2>/dev/null && mv "$TMP_CACHE" "$CACHE_FILE" || rm -f "$TMP_CACHE"
else
  jq -n --arg cwd "$CWD" --arg arch "$ARCHETYPE" --arg ctx "$BASE_CTX" --arg fk "$FRESH_KEY" \
    '{($cwd): {archetype: $arch, context: $ctx, freshKey: $fk}}' > "$CACHE_FILE"
fi

emit_ctx "$BASE_CTX"
