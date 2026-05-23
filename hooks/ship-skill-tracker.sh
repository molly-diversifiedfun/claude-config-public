#!/bin/bash
# Phase 8.1 (advisory) — Skill invocation tracker.
#
# Fires on every PostToolUse:Skill event. When a /ship run is active in cwd
# (i.e. `.ship/<run>/scope.json` exists), appends the invoked skill to
# `.ship/<run>/skills-invoked.log` (JSONL). Used by ship-skill-status.py +
# /system-retro to correlate which bindings actually fire vs which scope
# tiers ship well.
#
# Advisory only — NEVER blocks. Phase 8.1 deliberately stops short of
# enforcement because the N=28 dogfood (2026-05-23) showed superpowers
# scored worst on shipping (2.7) — enforcement of more superpowers might
# hurt /ship. Logging first; enforcement only if data later justifies it.
#
# Soft-fails open on every error path.
#
# Kill switch: SHIP_SKILL_TRACK=off
set -e

[ "${SHIP_SKILL_TRACK:-on}" = "off" ] && exit 0

# Drain stdin so the parent isn't blocked
INPUT=$(cat 2>/dev/null) || INPUT=""
[ -z "$INPUT" ] && exit 0

# Extract the invoked skill from tool_input.skill
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
[ -z "$SKILL" ] && exit 0

# Find the most-recent .ship/<run>/scope.json in cwd. If none, no active /ship
# run — silently ignore.
SHIP_DIR=""
if [ -d ".ship" ]; then
  SHIP_DIR=$(ls -t .ship/*/scope.json 2>/dev/null | head -1 | xargs -I {} dirname {} 2>/dev/null)
fi
[ -z "$SHIP_DIR" ] || [ ! -d "$SHIP_DIR" ] && exit 0

# Append JSONL: one line per invocation
LOG="$SHIP_DIR/skills-invoked.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","skill":"%s"}\n' "$TS" "$SKILL" >> "$LOG" 2>/dev/null || true

exit 0
