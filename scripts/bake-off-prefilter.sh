#!/usr/bin/env bash
# bake-off-prefilter.sh — pick mode-specific candidates for /bake-off
# Input:  $1 = full $ARGUMENTS string (may start with --yolo or --control)
# Output: mode|a|b|c|<query> on stdout, OR sentinel comment line.
# Exit 0 in all cases. Sentinels: # Empty query / # Unknown mode / # No candidates
#                                  / # Bake-off disabled

set +e

PREFILTER="$HOME/.claude/scripts/skills-prefilter.sh"
# Phase 7.4: stats file path is now lib-managed. BAKEOFF_STATS_FILE overrides.
# Sourcing the lib also gives us appearances_of, wins_of, losses_of, is_untried, is_eliminated.
# shellcheck source=bake-off-lib.sh
. "$(dirname "$0")/bake-off-lib.sh"
STATS_TSV="${BAKEOFF_STATS_FILE:-$HOME/.claude/data/bake-off-stats.tsv}"

# Kill switch
if [ "${BAKEOFF:-on}" = "off" ]; then
  echo "# Bake-off disabled (BAKEOFF=off)"
  exit 0
fi

INPUT="${1:-}"

# === Arg parsing: leading flag detection ===
MODE=""
QUERY=""
if [[ "$INPUT" =~ ^--yolo([[:space:]]|$) ]]; then
  MODE="yolo1"
  QUERY="${INPUT#--yolo}"; QUERY="${QUERY# }"
elif [[ "$INPUT" =~ ^--control([[:space:]]|$) ]]; then
  MODE="control2"
  QUERY="${INPUT#--control}"; QUERY="${QUERY# }"
elif [[ "$INPUT" =~ ^-- ]]; then
  FLAG=$(echo "$INPUT" | awk '{print $1}')
  echo "# Unknown mode: $FLAG. Use --yolo or --control."
  exit 0
else
  MODE="blind3"
  QUERY="$INPUT"
fi

# Empty / whitespace-only query
TRIMMED=$(printf '%s' "$QUERY" | tr -d '[:space:]')
if [ -z "$TRIMMED" ]; then
  echo "# Empty query — usage: /bake-off [--yolo|--control] 'what you want to do'"
  exit 0
fi

# === Get top-30 candidates from Phase 7.2 prefilter ===
PREFILTER_OUT=$(bash "$PREFILTER" "$QUERY" 2>/dev/null)

# Extract candidate names (skip sentinels and headers)
CANDIDATES=$(echo "$PREFILTER_OUT" | grep -v '^#' | awk -F'|' 'NF>=2 {print $1}')

if [ -z "$CANDIDATES" ]; then
  echo "# No candidates found — try broadening your query"
  exit 0
fi

# === Helper: appearances count for a skill ===
# Phase 7.4: removed inline definition; now provided by bake-off-lib.sh
# (sourced above). Lib version honors BAKEOFF_STATS_FILE for test isolation.

# Win-rate (returns "0" if no appearances or 0 wins+losses)
win_rate_of() {
  local skill="$1"
  [ -f "$STATS_TSV" ] || { echo "0"; return; }
  awk -F'\t' -v s="$skill" 'NR>1 && $1==s {
    apps=$2; wins=$3; losses=$4;
    decisions=wins+losses;
    if (decisions==0) { print "0"; found=1; exit }
    printf "%.6f\n", wins/decisions;
    found=1; exit
  } END { if (!found) print "0" }' "$STATS_TSV"
}

# Pick a single yolo from the candidate list (used by both yolo1 and control2; excludes optional name)
pick_yolo_from() {
  local exclude="${1:-}"
  local pool=""
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    [ "$n" = "$exclude" ] && continue
    is_eliminated "$n" && continue
    apps=$(appearances_of "$n")
    case "$apps" in ''|*[!0-9]*) apps=0 ;; esac
    if [ "$apps" -lt 3 ]; then
      pool="$pool$n"$'\n'
    fi
  done <<< "$CANDIDATES"
  pool=$(printf '%s' "$pool" | grep -v '^$')
  # Fallback to full candidates minus exclude AND minus eliminated.
  if [ -z "$pool" ]; then
    pool=""
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      [ "$n" = "$exclude" ] && continue
      is_eliminated "$n" && continue
      pool="$pool$n"$'\n'
    done <<< "$CANDIDATES"
    pool=$(printf '%s' "$pool" | grep -v '^$')
  fi
  local count; count=$(echo "$pool" | wc -l | tr -d ' ')
  [ "$count" -eq 0 ] && { echo ""; return; }
  local idx=$(( (RANDOM % count) + 1 ))
  echo "$pool" | sed -n "${idx}p"
}

# === Mode-specific selection ===
case "$MODE" in
  blind3)
    # Sort: <3 appearances first (alphabetical), then ≥3 (prefilter order preserved).
    UNTRIED=""
    TRIED=""
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      is_eliminated "$name" && continue
      apps=$(appearances_of "$name")
      case "$apps" in ''|*[!0-9]*) apps=0 ;; esac
      if [ "$apps" -lt 3 ]; then
        UNTRIED="$UNTRIED$name"$'\n'
      else
        TRIED="$TRIED$name"$'\n'
      fi
    done <<< "$CANDIDATES"
    # PRESERVE prefilter score-based order within each tier (do NOT alphabetize).
    # Phase 7.2.1 invested in semantic scoring; alphabetizing here destroys that signal.
    # Bug caught by NIGHT-12 smoke S1: empty stats → all "untried" → alphabetical sort
    # pushed semantically-irrelevant alphabet-A skills (ask-me-the-questions) into slot A.
    UNTRIED_KEEP=$(printf '%s' "$UNTRIED" | grep -v '^$')
    TRIED_KEEP=$(printf '%s' "$TRIED" | grep -v '^$')
    PICK=$(printf '%s\n%s\n' "$UNTRIED_KEEP" "$TRIED_KEEP" | grep -v '^$' | head -3)
    A=$(echo "$PICK" | sed -n '1p')
    B=$(echo "$PICK" | sed -n '2p')
    C=$(echo "$PICK" | sed -n '3p')
    echo "blind3|$A|$B|$C|$QUERY"
    ;;
  yolo1)
    PICK=$(pick_yolo_from "")
    if [ -z "$PICK" ]; then
      echo "# No candidates found — try broadening your query"
      exit 0
    fi
    echo "yolo1|$PICK||||$QUERY"
    ;;
  control2)
    # Pick known-good: highest win-rate among ≥3-appearance candidates.
    # Fallback: top-of-prefilter-score.
    BEST_NAME=""
    BEST_RATE="-1"
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      is_eliminated "$n" && continue
      apps=$(appearances_of "$n")
      case "$apps" in ''|*[!0-9]*) apps=0 ;; esac
      if [ "$apps" -ge 3 ]; then
        rate=$(win_rate_of "$n")
        if awk -v a="$rate" -v b="$BEST_RATE" 'BEGIN { exit !(a > b) }'; then
          BEST_RATE="$rate"
          BEST_NAME="$n"
        fi
      fi
    done <<< "$CANDIDATES"
    if [ -z "$BEST_NAME" ]; then
      while IFS= read -r n; do
        [ -z "$n" ] && continue
        is_eliminated "$n" && continue
        BEST_NAME="$n"
        break
      done <<< "$CANDIDATES"
    fi

    # Pick yolo excluding known-good
    YOLO=$(pick_yolo_from "$BEST_NAME")
    if [ -z "$YOLO" ]; then
      echo "# No candidates found — try broadening your query"
      exit 0
    fi
    echo "control2|$BEST_NAME|$YOLO|||$QUERY"
    ;;
esac
