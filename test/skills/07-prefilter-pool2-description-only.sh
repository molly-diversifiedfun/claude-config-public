#!/usr/bin/env bash
# Test: Phase 7.2.2 — Pool 2 membership requires description-line keyword match.
# Pre-7.2.2 bug: whole-file grep let body-only matches (example prompts,
# triggers, instructions) put always-on skills into Tier A with score=0,
# which then crowded out true semantic matches via alphabetical tiebreak
# ("ask-me-the-questions" beat "humanize-ai-writing" for humanize queries).
#
# Post-fix expectation:
#   - humanize-ai-writing (score≥2 from description) wins slot 1
#   - Tier C semantic matches (hooks, repurpose) appear in slots 2-3
#   - Always-on skills WITHOUT a description-match fall to Tier B
#     (alphabetical fallback at the bottom), not Tier A
#
# Keyword set "humanize paragraph less" chosen because:
#   - humanize-ai-writing's desc explicitly mentions "humanize"
#   - Generic always-on skills (devils-advocate, brand-voice-router,
#     superpowers:brainstorming) have NONE of these in their description
#   - Avoids overly-generic keywords like "make" that match too many descs
set -euo pipefail

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"

cd ~/github
OUT=$(bash "$PREFILTER" "humanize paragraph less" 2>&1)
RC=$?

if [ $RC -ne 0 ]; then
  echo "FAIL: prefilter exited non-zero ($RC): $OUT" >&2
  exit 1
fi

# Assertion 1: top candidate is humanize-ai-writing
TOP=$(echo "$OUT" | grep -vE '^#' | head -1 | awk -F'|' '{print $1}')
if [ "$TOP" != "humanize-ai-writing" ]; then
  echo "FAIL: top candidate should be humanize-ai-writing, got '$TOP'" >&2
  echo "Full output:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Assertion 2: a known body-only always-on skill (no humanize/paragraph/less
# in description) does NOT appear in the top 3 — confirming Pool 2 no longer
# admits body-only matches. Pre-fix, alphabetical-A always-on skills landed
# in Tier A; post-fix they only show in Tier B (after Tier A + Tier C).
TOP3_NAMES=$(echo "$OUT" | grep -vE '^#' | head -3 | awk -F'|' '{print $1}')
for body_only in ask-me-the-questions devils-advocate brand-voice-router; do
  if echo "$TOP3_NAMES" | grep -qx "$body_only"; then
    echo "FAIL: '$body_only' has no description match for humanize/paragraph/less" >&2
    echo "  but appears in top 3 — Pool 2 still admitting body-only matches." >&2
    echo "Top 3:" >&2
    echo "$TOP3_NAMES" >&2
    exit 1
  fi
done

# Assertion 3: when Pool 2 is description-only, total candidate count is
# meaningfully smaller. Pre-fix this query returned ~200 candidates (body
# noise). Post-fix should be well under 50.
TOTAL=$(echo "$OUT" | grep -oE '^# Candidates \([0-9]+ total' | grep -oE '[0-9]+' | head -1)
if [ -z "$TOTAL" ] || [ "$TOTAL" -gt 50 ]; then
  echo "FAIL: expected total candidate count ≤50 (description-only Pool 2)," >&2
  echo "  got $TOTAL. Body noise may still be leaking through." >&2
  echo "$OUT" | head -5 >&2
  exit 1
fi

echo "PASS"
