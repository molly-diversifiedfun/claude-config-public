#!/bin/bash
# Empty projects dir → empty report, no crash, no LLM call.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/projects"

export SHIP_SCOPE_REPLAY_PROJECTS_DIR="$TMP/projects"
export SHIP_SCOPE_REPLAY_CLASSIFIER="/nonexistent-should-not-be-called"
export SHIP_SCOPE_REPLAY_REPORT_DIR="$TMP/reports"

OUT=$(python3 ~/.claude/scripts/ship-scope-replay.py 5 2>&1)
echo "$OUT" | grep -q "discovered 0 sessions" || { echo "expected 'discovered 0 sessions': $OUT"; exit 1; }
echo "04-empty-corpus: OK"
