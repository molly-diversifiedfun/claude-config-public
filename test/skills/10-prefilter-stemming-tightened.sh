#!/usr/bin/env bash
# Test: Phase 7.2.3 — tightened stemming pattern eliminates the over-eager
# prefix-match false positive class. Pre-7.2.3 `\b<kw>` (unbounded prefix)
# matched `\bmake` against the literal "decision-maker" inside descriptions,
# falsely scoring `devils-advocate` for the keyword "make".
#
# Post-7.2.3 the pattern is `\b<kw>(s|es|d|ed|ing)?\b` — controlled regular-suffix
# stems with trailing word-boundary. Regular stems still match (writing matches
# write+ing); within-word collisions don't.
#
# Also verifies the new STOPWORDS additions (use, skill, any, should, before).
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"

cd ~/github

# Assertion 1: stemming tightening — query "humanize this paragraph and make it less AI".
# devils-advocate description contains "decision-maker" but no semantic match for
# humanize/paragraph/make/less. Pre-7.2.3 it scored 1 via `\bmake` matching
# `maker`. Post-7.2.3 it should NOT appear in the top 5.
OUT=$(bash "$PREFILTER" "humanize this paragraph and make it less AI" 2>&1)
TOP5=$(echo "$OUT" | grep -vE '^#' | head -5 | awk -F'|' '{print $1}')
if echo "$TOP5" | grep -qx "devils-advocate"; then
  echo "FAIL: devils-advocate should NOT appear in top 5 (no semantic match — its only" >&2
  echo "  pre-7.2.3 'score' came from \\bmake matching 'decision-maker' in description)." >&2
  echo "Top 5: $TOP5" >&2
  exit 1
fi

# Assertion 2: stemming still works for legitimate regular stems.
# Query "writing copy" should match copywriting via `write+ing`. Pre-7.2.3 this
# worked via prefix; post-7.2.3 must still work via the (s|es|d|ed|ing) suffix set.
OUT2=$(bash "$PREFILTER" "writing copy" 2>&1)
if ! echo "$OUT2" | grep -vE '^#' | awk -F'|' '$1 ~ /^(copy|write|writing)/ {found=1; exit} END{exit !found}'; then
  echo "FAIL: query 'writing copy' should surface a writing/copy skill in output." >&2
  echo "Top 5:" >&2
  echo "$OUT2" | head -8 >&2
  exit 1
fi

# Assertion 3: stopword additions take effect.
# Query "use any skill" should tokenize to ZERO non-stopword keywords (all three
# are now stopwords) → empty-query sentinel.
OUT3=$(bash "$PREFILTER" "use any skill" 2>&1)
if ! echo "$OUT3" | grep -qE "^# Empty query"; then
  echo "FAIL: query 'use any skill' (all stopwords) should emit empty-query sentinel." >&2
  echo "Got: $OUT3" >&2
  exit 1
fi

echo "PASS"
