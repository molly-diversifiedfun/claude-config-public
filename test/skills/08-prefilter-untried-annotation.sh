#!/usr/bin/env bash
# Test: Phase 7.4 — skills-prefilter.sh emits a 4th column "untried" or empty.
# Renders nothing visible itself; the /skills slash command body uses col 4
# to prefix "✨ " when displaying the top 5.
#
# Fixture strategy: mktemp -d + BAKEOFF_STATS_FILE override so this test
# NEVER reads or writes live data files (per
# feedback_test_fixtures_must_not_write_live_data_files.md).
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture: humanize-ai-writing has 2 apps (untried), brand-voice-router has
# 3 apps with 1 win (NOT untried), copywriting has no row (untried by default).
cat > "$TMPDIR/stats.tsv" <<'EOF'
skill_name	appearances	wins	losses	last_run_iso
humanize-ai-writing	2	1	1	2026-05-21T00:00:00Z
brand-voice-router	3	1	2	2026-05-21T00:00:00Z
EOF

export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"

cd ~/github
OUT=$(bash "$PREFILTER" "humanize paragraph less" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: prefilter exited non-zero ($RC): $OUT" >&2
  exit 1
fi

# Helper: get column 4 of the line whose column 1 equals $1.
col4_for() {
  echo "$OUT" | grep -vE '^#' | awk -F'|' -v s="$1" '$1==s {print $4; exit}'
}

# Assertion 1: humanize-ai-writing (2 apps) → col 4 == "untried"
HUM_C4=$(col4_for "humanize-ai-writing")
if [ "$HUM_C4" != "untried" ]; then
  echo "FAIL: humanize-ai-writing (2 apps) col 4 should be 'untried', got '$HUM_C4'" >&2
  echo "Full output:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Assertion 2: brand-voice-router (3 apps, 1 win) → col 4 empty
# (only check if brand-voice-router actually appears in output for this query)
BVR_LINE=$(echo "$OUT" | grep -vE '^#' | awk -F'|' '$1=="brand-voice-router" {print; exit}')
if [ -n "$BVR_LINE" ]; then
  BVR_C4=$(echo "$BVR_LINE" | awk -F'|' '{print $4}')
  if [ "$BVR_C4" = "untried" ]; then
    echo "FAIL: brand-voice-router (3 apps, 1 win) col 4 should NOT be 'untried', got '$BVR_C4'" >&2
    exit 1
  fi
fi

# Assertion 3: copywriting (no row → 0 apps → untried) → col 4 == "untried"
# (only check if copywriting appears for this query)
COPY_LINE=$(echo "$OUT" | grep -vE '^#' | awk -F'|' '$1=="copywriting" {print; exit}')
if [ -n "$COPY_LINE" ]; then
  COPY_C4=$(echo "$COPY_LINE" | awk -F'|' '{print $4}')
  if [ "$COPY_C4" != "untried" ]; then
    echo "FAIL: copywriting (no row, 0 apps) col 4 should be 'untried', got '$COPY_C4'" >&2
    exit 1
  fi
fi

# Assertion 4: column 1 is a clean name (no '✨', no leading whitespace).
# Defends the bake-off-prefilter consumer contract — it reads col 1 verbatim
# for stats lookups, so any prefix would break lookups.
DIRTY=$(echo "$OUT" | grep -vE '^#' | awk -F'|' '$1 ~ /^[ \t✨]/ {print; exit}')
if [ -n "$DIRTY" ]; then
  echo "FAIL: column 1 contains prefix or whitespace — breaks downstream stats lookups." >&2
  echo "Offending line: $DIRTY" >&2
  exit 1
fi

echo "PASS"
