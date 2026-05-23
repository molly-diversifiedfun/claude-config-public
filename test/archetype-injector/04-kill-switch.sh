#!/usr/bin/env bash
set -euo pipefail
HOOK="$HOME/.claude/hooks/archetype-injector.sh"

INPUT='{"cwd":"$HOME/github/<your-bot>","prompt":""}'
OUT=$(echo "$INPUT" | ARCHETYPE_GATE=off "$HOOK")

if [ "$(echo "$OUT" | jq -c .)" != "{}" ]; then
  echo "FAIL: kill switch should return {}. Got: $OUT" >&2
  exit 1
fi
echo "PASS"
