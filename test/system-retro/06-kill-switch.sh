#!/bin/bash
# SYSTEM_RETRO=off short-circuits the script.
set -e
OUT=$(SYSTEM_RETRO=off python3 ~/.claude/scripts/system-retro.py 2>&1)
echo "$OUT" | grep -q "disabled" || { echo "expected 'disabled' in output: $OUT"; exit 1; }
echo "06-kill-switch: OK"
