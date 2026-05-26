#!/usr/bin/env bash
# Bash entry point for manifest validation.
# Kill switch: MANIFEST_GATE=off
set +e

if [ "$MANIFEST_GATE" = "off" ]; then
  echo "# manifest validation disabled (MANIFEST_GATE=off)"
  exit 0
fi

MANIFEST_PATH="${MANIFEST_PATH:-$HOME/.claude/agent-skill-manifest.yaml}"

if [ ! -f "$MANIFEST_PATH" ]; then
  echo "# error: manifest not found at $MANIFEST_PATH" >&2
  exit 2
fi

python3 "$HOME/.claude/scripts/validate-manifest.py" "$MANIFEST_PATH"
