#!/bin/bash
# carl-loader.sh — UserPromptSubmit hook
# Loads CARL domains based on user prompt keywords and star-commands.
# Input: JSON on stdin { "prompt": "...", "cwd": "..." }
# Output: JSON { "additionalContext": "..." } or {}

CARL_GLOBAL="$HOME/.carl"

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)

# Capture last prompt for downstream hooks (audience-gate, scope check)
mkdir -p "$HOME/.claude/checkpoints"
echo "$PROMPT" > "$HOME/.claude/checkpoints/last_prompt"

if [ -z "$PROMPT" ]; then echo '{}'; exit 0; fi

CARL_DIR="$CARL_GLOBAL"
[ -f "$CWD/.carl/manifest" ] && CARL_DIR="$CWD/.carl"
[ -f "$CARL_DIR/manifest" ] || { echo '{}'; exit 0; }

# Merge local + global manifests (local entries win, global fills gaps)
TMPMAN=$(mktemp)
if [ "$CARL_DIR" != "$CARL_GLOBAL" ] && [ -f "$CARL_GLOBAL/manifest" ]; then
  # Start with global, overlay local
  tr -d '\r' < "$CARL_GLOBAL/manifest" > "$TMPMAN"
  tr -d '\r' < "$CARL_DIR/manifest" >> "$TMPMAN"
else
  tr -d '\r' < "$CARL_DIR/manifest" > "$TMPMAN"
fi
trap "rm -f '$TMPMAN'" EXIT

PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

mval() { grep "^${1}=" "$TMPMAN" 2>/dev/null | head -1 | cut -d'=' -f2-; }

# Collect which domains+files to load into a temp file (avoids all subshell issues)
LOAD_LIST=$(mktemp)

# 1. ALWAYS_ON domains
AO_DOMAINS=$(grep "_ALWAYS_ON=true" "$TMPMAN" | sed 's/_ALWAYS_ON=true//' | grep -v "^#")
for d in $AO_DOMAINS; do
  s=$(mval "${d}_STATE")
  if [ "$s" = "active" ]; then
    dl=$(echo "$d" | tr '[:upper:]' '[:lower:]')
    echo "$d $CARL_DIR/$dl" >> "$LOAD_LIST"
  fi
done

# 2. Keyword-triggered domains
RECALL_LINES=$(grep "_RECALL=" "$TMPMAN" | grep -v "^#")
LOADED_AO="$AO_DOMAINS"
while IFS= read -r recline; do
  [ -z "$recline" ] && continue
  k="${recline%%=*}"
  v="${recline#*=}"
  d="${k%_RECALL}"

  # Skip already loaded
  skip_ao=false
  for ao in $LOADED_AO; do
    [ "$ao" = "$d" ] && { skip_ao=true; break; }
  done
  [ "$skip_ao" = true ] && continue

  s=$(mval "${d}_STATE")
  [ "$s" = "active" ] || continue

  # Check excludes
  exc=$(mval "${d}_EXCLUDE")
  excluded=false
  if [ -n "$exc" ]; then
    IFS=',' read -ra ew <<< "$exc"
    for w in "${ew[@]}"; do
      w=$(echo "$w" | xargs | tr '[:upper:]' '[:lower:]')
      [ -n "$w" ] && [[ "$PROMPT_LOWER" == *"$w"* ]] && { excluded=true; break; }
    done
  fi
  [ "$excluded" = true ] && continue

  # Check keywords
  IFS=',' read -ra kws <<< "$v"
  hit=false
  for kw in "${kws[@]}"; do
    kw=$(echo "$kw" | xargs | tr '[:upper:]' '[:lower:]')
    [ -n "$kw" ] && [[ "$PROMPT_LOWER" == *"$kw"* ]] && { hit=true; break; }
  done

  if [ "$hit" = true ]; then
    dl=$(echo "$d" | tr '[:upper:]' '[:lower:]')
    echo "$d $CARL_DIR/$dl" >> "$LOAD_LIST"
  fi
done <<< "$RECALL_LINES"

# 3. Star-commands
if [[ "$PROMPT" =~ \*([a-z]+) ]]; then
  sc=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
  cs=$(mval "COMMANDS_STATE")
  if [ "$cs" = "active" ]; then
    if [ -f "$CARL_DIR/commands" ]; then
      echo "$sc $CARL_DIR/commands" >> "$LOAD_LIST"
    fi
    # Also check global commands if local didn't have the star-command
    if [ "$CARL_DIR" != "$CARL_GLOBAL" ] && [ -f "$CARL_GLOBAL/commands" ]; then
      echo "$sc $CARL_GLOBAL/commands" >> "$LOAD_LIST"
    fi
  fi
fi

# 4. Context bracket
CFILE="$HOME/.claude/checkpoints/.tool_count"
if [ -f "$CFILE" ] && [ -f "$CARL_DIR/context" ]; then
  tc=$(cat "$CFILE" 2>/dev/null || echo "0")
  if [ "$tc" -gt 200 ]; then br="DEPLETED"
  elif [ "$tc" -gt 100 ]; then br="MODERATE"
  else br="FRESH"; fi
  ben=$(tr -d '\r' < "$CARL_DIR/context" | grep "^${br}_RULES=" | head -1 | cut -d'=' -f2-)
  [ "$ben" = "true" ] && echo "$br $CARL_DIR/context" >> "$LOAD_LIST"
fi

# Now load all rules from the list using fd 3 to avoid nested read conflicts
CONTEXT=""
while IFS=' ' read -r domain filepath <&3; do
  [ -z "$domain" ] || [ -z "$filepath" ] && continue
  # Fall through to global if local file missing
  if [ ! -f "$filepath" ] && [ "$CARL_DIR" != "$CARL_GLOBAL" ]; then
    filepath="$CARL_GLOBAL/$(basename "$filepath")"
  fi
  [ -f "$filepath" ] || continue
  while IFS= read -r rl; do
    rl="${rl%$'\r'}"
    case "$rl" in \#*|"") continue ;; esac
    case "$rl" in ${domain}_RULE_*) CONTEXT+="- ${rl#*=}"$'\n' ;; esac
  done < "$filepath"
  CONTEXT+=$'\n'
done 3< "$LOAD_LIST"

rm -f "$LOAD_LIST"

if [ -n "$CONTEXT" ]; then
  jq -n --arg ctx "[CARL Rules]
$CONTEXT" '{"additionalContext": $ctx}'
else
  echo '{}'
fi

exit 0
