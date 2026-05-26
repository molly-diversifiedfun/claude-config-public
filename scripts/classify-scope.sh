#!/usr/bin/env bash
# Phase 8.x.1 — manifest-dispatch scope classifier.
#
# Reads --prompt + --jtbd-default; emits S|M|L|XL to stdout.
#
# Precedence (spec OQ7 "manifest wins on low confidence"):
#   1. Deterministic regex match on prompt for S or XL signal → emit that.
#   2. Otherwise → emit --jtbd-default.
# Prompt-context override fires ONLY on high-confidence keyword hits.
# Ambiguous prompts fall back to the manifest's declared default.
#
# Kill switch: CLASSIFY_SCOPE=off → always emits --jtbd-default.

set -euo pipefail

PROMPT=""
DEFAULT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --prompt)        PROMPT="${2:-}"; shift 2 ;;
    --jtbd-default)  DEFAULT="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$DEFAULT" in
  S|M|L|XL) ;;
  *) echo "missing or invalid --jtbd-default (need S|M|L|XL)" >&2; exit 2 ;;
esac

if [ "${CLASSIFY_SCOPE:-on}" = "off" ]; then
  echo "$DEFAULT"
  exit 0
fi

if [ -z "$PROMPT" ]; then
  echo "$DEFAULT"
  exit 0
fi

lc=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

# XL signals — architectural / framework-level work.
if printf '%s' "$lc" | grep -Eq '(\barchitectural\b|\bnew service\b|\brewrite\b|\bbreaking redesign\b|\bframework (swap|change|migration)\b|\bmonorepo (split|merge)\b)'; then
  echo "XL"
  exit 0
fi

# S signals — tiny self-contained edit.
if printf '%s' "$lc" | grep -Eq '(\btypo\b|\benv var\b|\b(one|single)[- ]?liner\b|\b(add|fix|update) (a |an |one )?comment(s)?\b|\b(rename|rename a|rename the) [a-z_][a-z0-9_]*\b|\bdep(endency)? bump\b|\bconfig (tweak|change|nudge)\b|\bone[- ]line (fix|change)\b)'; then
  echo "S"
  exit 0
fi

# No confident override — manifest default wins.
echo "$DEFAULT"
