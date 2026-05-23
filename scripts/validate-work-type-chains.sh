#!/usr/bin/env bash
# validate-work-type-chains.sh — YAML shape + work-type vocabulary check
# for ~/.claude/work-type-chains.yaml.
#
# Usage: bash validate-work-type-chains.sh [path]
# Default: ~/.claude/work-type-chains.yaml
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

MANIFEST="${1:-$HOME/.claude/work-type-chains.yaml}"

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: chain manifest not found at $MANIFEST" >&2
  exit 1
fi

VALID_WORK_TYPES="build plan review debug research write-content memory design infra"

FAIL=0
LINE=0
FOUND_TYPES=""

while IFS= read -r line; do
  LINE=$((LINE + 1))
  case "$line" in
    ""|\#*) continue ;;
  esac

  # Top-level key: must be one of the 9 valid work-types
  if echo "$line" | grep -qE '^[a-z][a-z-]+:$'; then
    KEY=$(echo "$line" | sed 's/:$//')
    found=0
    for v in $VALID_WORK_TYPES; do
      if [ "$KEY" = "$v" ]; then found=1; break; fi
    done
    if [ "$found" -eq 0 ]; then
      echo "FAIL line $LINE: invalid work-type '$KEY' (allowed: $VALID_WORK_TYPES)" >&2
      FAIL=1
    else
      FOUND_TYPES="$FOUND_TYPES $KEY"
    fi
    continue
  fi

  # Chain entry: must be '  - <skill-name>'
  if ! echo "$line" | grep -qE '^  - [^ ]+'; then
    echo "FAIL line $LINE: invalid shape — expected '  - <skill>', got: $line" >&2
    FAIL=1
  fi
done < "$MANIFEST"

# Check that all 9 work-types are present
for v in $VALID_WORK_TYPES; do
  if ! echo "$FOUND_TYPES" | grep -qE "(^| )$v( |$)"; then
    echo "FAIL: missing required work-type '$v' in $MANIFEST" >&2
    FAIL=1
  fi
done

if [ $FAIL -eq 0 ]; then
  COUNT=$(grep -cE '^  - ' "$MANIFEST")
  echo "PASS: $MANIFEST (9 work-types, $COUNT chain entries)"
  exit 0
fi
exit 1
