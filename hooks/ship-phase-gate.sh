#!/bin/bash
# ship-phase-gate.sh — Claude Code PostToolUse hook.
# Gates Stage 9 (Deploy + Smoke) of /ship pipeline v2.
#
# Activation: only fires when an ancestor of cwd contains .ship/<run>/patterns.md
# (within MAX_ANCESTOR_LEVELS=4 levels). Otherwise silent exit 0.
#
# Reads: tool-call JSON on stdin (currently ignored — kept for future use).
# Reads: <run>/deploy-log.md to check Stage 9 gates.
# Writes: hook-protocol JSON on stdout iff a gate fires:
#   {"decision":"block","reason":"..."}  → 3+ deploys without ## Pivot decision
#   {"decision":"warn","reason":"..."}   → missing ## Observability: or ## Smoke test:
# Exits: always 0. Non-zero would be treated as hook error by Claude Code.
#
# See spec: docs/superpowers/specs/2026-05-10-ship-pipeline-v2-design.md §9
# Kill switch: SHIP_PHASE_GATE=off → exit 0 immediately (no-op).

set -euo pipefail

if [ "${SHIP_PHASE_GATE:-on}" = "off" ]; then
  exit 0
fi

readonly MAX_ANCESTOR_LEVELS=4
readonly DEPLOY_RULE_THRESHOLD=3

# Drain stdin (Claude Code passes tool-call JSON; we don't currently parse it).
cat >/dev/null 2>&1 || true

warn_if_missing() {
  local pattern="$1" reason="$2"
  if ! grep -q "$pattern" "$DEPLOY_LOG"; then
    printf '{"decision":"warn","reason":"%s"}\n' "$reason"
    exit 0
  fi
}

# Find the active ship run (closest .ship dir, then newest run inside)
# Walk up from cwd looking for .ship dir, max MAX_ANCESTOR_LEVELS levels up
SHIP_DIR=""
DIR="$PWD"
for _ in $(seq 0 "$MAX_ANCESTOR_LEVELS"); do
  if [ -d "$DIR/.ship" ]; then
    SHIP_DIR="$DIR/.ship"
    break
  fi
  PARENT=$(dirname "$DIR")
  [ "$PARENT" = "$DIR" ] && break
  DIR="$PARENT"
done
[ -z "$SHIP_DIR" ] && exit 0

# Sort by directory name (date-prefixed YYYY-MM-DD-<slug>); newest first.
RUN_DIR=$(ls -1d "$SHIP_DIR"/*/ 2>/dev/null | sort -r | head -1)
[ -z "$RUN_DIR" ] && exit 0
[ -f "$RUN_DIR/patterns.md" ] || exit 0

DEPLOY_LOG="$RUN_DIR/deploy-log.md"
[ -f "$DEPLOY_LOG" ] || exit 0

# 3-deploy-rule: count deploy attempts; require pivot section after threshold.
# Use `|| true` (not `|| echo 0`) so grep's exit-1-on-no-match doesn't append a
# second "0" to DEPLOY_COUNT. Default to 0 if empty.
DEPLOY_COUNT=$(grep -c "^## Deploy attempt" "$DEPLOY_LOG" 2>/dev/null || true)
DEPLOY_COUNT=${DEPLOY_COUNT:-0}
if [ "$DEPLOY_COUNT" -ge "$DEPLOY_RULE_THRESHOLD" ]; then
  if ! grep -q "^## Pivot decision" "$DEPLOY_LOG"; then
    cat <<'JSON'
{"decision":"block","reason":"3-deploy rule triggered: 3+ deploys without convergence. Add a `## Pivot decision` section to deploy-log.md before next deploy. See learned/deploy-iteration-discipline.md."}
JSON
    exit 0
  fi
fi

# Observability/smoke checks only meaningful once a deploy has been logged.
# Pre-deploy state should be silent — no false warnings before Stage 9 starts.
[ "$DEPLOY_COUNT" -eq 0 ] && exit 0

warn_if_missing "^## Observability:" "Stage 9 gate: deploy-log.md missing Observability declaration. Confirm runtime logs are visible before next push."
warn_if_missing "^## Smoke test:" "Stage 9 gate: deploy-log.md missing Smoke test section. Run e2e plugin or document manual smoke."

exit 0
