#!/bin/bash
# record-audience.sh — write audience answer for a (project, deliverable) key.
# State is project-scoped and persistent — no session_id involved.
#   Record: record-audience.sh <key> <audience>
#   Reset:  record-audience.sh <key> ""
# Spec: docs/superpowers/specs/2026-05-15-claude-setup-enforcement-gates-design.md
# v1.1 (2026-05-16): drop session_id; single audience.json file

set -u

KEY="${1:?missing project_deliverable key (e.g. <your-web-app-1>_carousel)}"
AUDIENCE="${2?missing audience argument (use empty string \"\" to reset)}"

STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/audience.json"

mkdir -p "$STATE_DIR"
[ -f "$STATE_FILE" ] || echo '{}' > "$STATE_FILE"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP=$(mktemp)

if [ -z "$AUDIENCE" ]; then
  jq --arg k "$KEY" 'del(.[$k])' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "Cleared: $KEY"
else
  jq --arg k "$KEY" --arg a "$AUDIENCE" --arg t "$TS" \
     '.[$k] = {"audience": $a, "ts": $t}' \
     "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "Recorded: $KEY = $AUDIENCE"
fi
