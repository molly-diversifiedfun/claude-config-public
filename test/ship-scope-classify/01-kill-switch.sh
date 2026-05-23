#!/bin/bash
# SHIP_SCOPE=off short-circuits to scope=M with a clear rationale.
set -e
OUT=$(SHIP_SCOPE=off python3 ~/.claude/scripts/ship-scope-classify.py "anything")
echo "$OUT" | grep -q '"scope": "M"' || { echo "expected scope=M: $OUT"; exit 1; }
echo "$OUT" | grep -q 'disabled' || { echo "expected 'disabled' rationale: $OUT"; exit 1; }
echo "01-kill-switch: OK"
