#!/bin/bash
# check-model-freshness.sh — SessionStart hook (lightweight)
# Warns if model references in performance.md are >90 days old.
# Reads the FRESHNESS comment date, compares to today.

PERF_FILE="$HOME/.claude/rules/common/performance.md"

if [ ! -f "$PERF_FILE" ]; then
  echo '{}'
  exit 0
fi

# Extract freshness date from comment
FRESHNESS_DATE=$(grep -o 'last verified [0-9-]*' "$PERF_FILE" | head -1 | sed 's/last verified //')

if [ -z "$FRESHNESS_DATE" ]; then
  echo '{"systemMessage":"MODEL FRESHNESS: No verification date found in performance.md. Add <!-- FRESHNESS: last verified YYYY-MM-DD --> comment."}'
  exit 0
fi

# Calculate days since last verification
TODAY=$(date +%s)
VERIFIED=$(date -j -f "%Y-%m-%d" "$FRESHNESS_DATE" +%s 2>/dev/null || date -d "$FRESHNESS_DATE" +%s 2>/dev/null || echo "0")

if [ "$VERIFIED" = "0" ]; then
  echo '{}'
  exit 0
fi

DAYS_OLD=$(( (TODAY - VERIFIED) / 86400 ))

if [ "$DAYS_OLD" -gt 90 ]; then
  echo "{\"systemMessage\":\"MODEL FRESHNESS WARNING: Model references in performance.md are ${DAYS_OLD} days old (last verified $FRESHNESS_DATE). Check https://docs.anthropic.com/en/docs/about-claude/models for updates and update the file + FRESHNESS date.\"}"
else
  echo '{}'
fi

exit 0
