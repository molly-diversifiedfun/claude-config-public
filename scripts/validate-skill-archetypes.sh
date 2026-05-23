#!/usr/bin/env bash
# validate-skill-archetypes.sh — YAML shape + archetype-vocabulary check
# for ~/.claude/skill-archetypes.yaml.
#
# Usage: bash validate-skill-archetypes.sh [path-to-yaml]
# Default path: ~/.claude/skill-archetypes.yaml
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

MANIFEST="${1:-$HOME/.claude/skill-archetypes.yaml}"

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: manifest not found at $MANIFEST" >&2
  exit 1
fi

# Vocabulary (must stay in sync with projects.yaml + spec)
VALID_ARCHETYPES="web-app telegram-bot content-pipeline python-cli video-pipeline infra-config brand-content always-on"

FAIL=0
LINE=0

while IFS= read -r line; do
  LINE=$((LINE + 1))
  case "$line" in
    ""|\#*) continue ;;
  esac

  # Expected shape: "skill-name": [archetype1, archetype2, ...]
  if ! echo "$line" | grep -qE '^"[^"]+":[[:space:]]*\[[^][]+\]$'; then
    echo "FAIL line $LINE: invalid shape — expected '\"name\": [archetypes]', got: $line" >&2
    FAIL=1
    continue
  fi

  # Extract archetype list
  archs=$(echo "$line" | sed -E 's/^"[^"]+":[[:space:]]*\[([^][]+)\].*/\1/' | tr ',' ' ')

  for a in $archs; do
    a_trim=$(echo "$a" | tr -d ' ')
    [ -z "$a_trim" ] && continue
    found=0
    for v in $VALID_ARCHETYPES; do
      if [ "$a_trim" = "$v" ]; then found=1; break; fi
    done
    if [ "$found" -eq 0 ]; then
      echo "FAIL line $LINE: invalid archetype '$a_trim' (allowed: $VALID_ARCHETYPES)" >&2
      FAIL=1
    fi
  done
done < "$MANIFEST"

if [ $FAIL -eq 0 ]; then
  COUNT=$(grep -c '^"' "$MANIFEST")
  echo "PASS: $MANIFEST ($COUNT entries)"
  exit 0
fi
exit 1
