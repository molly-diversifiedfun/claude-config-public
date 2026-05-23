#!/bin/bash
# Empty ask defaults to S without any LLM call (cheap path).
set -e
OUT=$(echo "" | python3 ~/.claude/scripts/ship-scope-classify.py)
echo "$OUT" | grep -q '"scope": "S"' || { echo "expected S on empty: $OUT"; exit 1; }
echo "$OUT" | grep -q "empty" || { echo "expected empty rationale: $OUT"; exit 1; }
echo "05-empty-input: OK"
