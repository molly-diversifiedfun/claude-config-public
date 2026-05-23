#!/usr/bin/env bash
# Test: Phase 7.4 — skills with ≥3 appearances AND 0 wins are dropped from
# skills-prefilter.sh output entirely. BAKEOFF_ELIMINATE=off kill switch
# brings them back.
#
# Fixture strategy: mktemp -d + BAKEOFF_STATS_FILE override.
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture: humanize-ai-writing has 3 apps + 0 wins → ELIMINATED
#          brand-voice-router has 3 apps + 1 win → NOT eliminated (has a win)
cat > "$TMPDIR/stats.tsv" <<'EOF'
skill_name	appearances	wins	losses	last_run_iso
humanize-ai-writing	3	0	3	2026-05-21T00:00:00Z
brand-voice-router	3	1	2	2026-05-21T00:00:00Z
EOF

export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"

cd ~/github

# Assertion 1: humanize-ai-writing (eliminated) is ABSENT from output
OUT=$(bash "$PREFILTER" "humanize paragraph less" 2>&1)
if echo "$OUT" | grep -vE '^#' | awk -F'|' '$1=="humanize-ai-writing" {found=1; exit} END{exit !found}' >/dev/null 2>&1; then
  echo "FAIL: humanize-ai-writing (3 apps, 0 wins) should be dropped from output." >&2
  echo "Output:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Assertion 2: with BAKEOFF_ELIMINATE=off, humanize-ai-writing returns
OUT_KILL=$(BAKEOFF_ELIMINATE=off bash "$PREFILTER" "humanize paragraph less" 2>&1)
if ! echo "$OUT_KILL" | grep -vE '^#' | awk -F'|' '$1=="humanize-ai-writing" {found=1; exit} END{exit !found}' >/dev/null 2>&1; then
  echo "FAIL: BAKEOFF_ELIMINATE=off should bring humanize-ai-writing back into output." >&2
  echo "Output:" >&2
  echo "$OUT_KILL" >&2
  exit 1
fi

# Assertion 3: brand-voice-router (3 apps, 1 win) is NOT eliminated
# (only check if brand-voice-router appears in the query; with the query
# above it may not — pick a query that surfaces it)
OUT2=$(bash "$PREFILTER" "brand voice content" 2>&1)
if ! echo "$OUT2" | grep -vE '^#' | awk -F'|' '$1=="brand-voice-router" {found=1; exit} END{exit !found}' >/dev/null 2>&1; then
  echo "FAIL: brand-voice-router (3 apps, 1 win) should NOT be eliminated; expected in output for 'brand voice content' query." >&2
  echo "Output:" >&2
  echo "$OUT2" >&2
  exit 1
fi

echo "PASS"
