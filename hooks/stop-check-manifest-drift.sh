#!/usr/bin/env bash
# Stop hook that detects drift between current agent.md files and what
# render-manifest.py would produce. Logs but does NOT block.
# Kill switch: MANIFEST_DRIFT_CHECK=off
set +e

if [ "$MANIFEST_DRIFT_CHECK" = "off" ]; then
  exit 0
fi

# Skip until agents/ is generated (Task 7 cutover lands agents-v2/ into agents/).
# Until then, drift check would always fire false-positive against legacy hand-maintained agents.
if [ ! -f "$HOME/.claude/agents/.generated-from-manifest" ]; then
  exit 0
fi

LOG="$HOME/.claude/logs/manifest-drift.log"
mkdir -p "$(dirname "$LOG")"

OUT=$(AGENTS_OUT_DIR="$HOME/.claude/agents" python3 "$HOME/.claude/scripts/render-manifest.py" --check 2>&1)
RC=$?

if [ "$RC" -ne 0 ]; then
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"ts\":\"$TS\",\"hook\":\"stop-check-manifest-drift\",\"result\":$(echo "$OUT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" >> "$LOG"
fi

exit 0
