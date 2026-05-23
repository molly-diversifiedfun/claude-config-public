#!/bin/bash
set -e
OUT=$(SHIP_SCOPE_REPLAY=off python3 ~/.claude/scripts/ship-scope-replay.py 2>&1)
echo "$OUT" | grep -q "disabled" || { echo "expected 'disabled': $OUT"; exit 1; }
echo "01-kill-switch: OK"
