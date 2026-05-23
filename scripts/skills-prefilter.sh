#!/usr/bin/env bash
# skills-prefilter.sh — produce ≤30 candidate skills for /skills 'query'.
# Inputs:  $1 = query string (from /skills slash command's $ARGUMENTS)
# Outputs: structured candidate lines on stdout, one per line:
#          <name>|<archetypes-csv>|<60-char-description-excerpt>
# Exit 0 in all cases. Empty query, no matches, and kill-switch states all
# emit a sentinel comment line; the slash command body handles them.

set +e

MANIFEST="$HOME/.claude/skill-archetypes.yaml"
PROJECTS="$HOME/.claude/projects.yaml"
PERSONAL_SKILLS_DIR="$HOME/.claude/skills"
PLUGIN_CACHE_DIR="$HOME/.claude/plugins/cache"

# Kill switch
if [ "${SKILLS_CATALOG:-on}" = "off" ]; then
  echo "# Catalog disabled (SKILLS_CATALOG=off)"
  exit 0
fi

# Phase 7.4: source shared bake-off stats helpers (appearances_of, wins_of,
# is_untried, is_eliminated). Sourced after kill-switch so a disabled
# catalog doesn't waste cycles loading the lib.
# shellcheck source=bake-off-lib.sh
. "$(dirname "$0")/bake-off-lib.sh"

QUERY="${1:-}"

# Empty / whitespace-only
TRIMMED=$(printf '%s' "$QUERY" | tr -d '[:space:]')
if [ -z "$TRIMMED" ]; then
  echo "# Empty query — usage: /skills 'what you want to do'"
  exit 0
fi

# === Archetype resolution (mirrors archetype-injector.sh logic) ===
CWD="${PWD:-$HOME}"
ARCHETYPE=""

if [ -f "$PROJECTS" ]; then
  CWD_NORM=$(echo "$CWD" | sed "s|^$HOME|~|")
  ARCHETYPE=$(grep -E "^\"$CWD_NORM\":" "$PROJECTS" 2>/dev/null | head -1 | sed -E 's/^"[^"]+":[[:space:]]*//' | tr -d ' "')

  if [ -z "$ARCHETYPE" ]; then
    BEST_LEN=0
    while IFS= read -r line; do
      PREFIX=$(echo "$line" | sed -E 's/^"([^"]+)":.*/\1/')
      LEN=${#PREFIX}
      PREFIX_EXPANDED="${PREFIX/#~/$HOME}"
      case "$CWD" in
        "$PREFIX_EXPANDED"/*|"$PREFIX_EXPANDED")
          if [ "$LEN" -gt "$BEST_LEN" ]; then
            BEST_LEN=$LEN
            ARCHETYPE=$(echo "$line" | sed -E 's/^"[^"]+":[[:space:]]*//' | tr -d ' "')
          fi
          ;;
      esac
    done < <(grep -E '^"[^"]+":' "$PROJECTS" 2>/dev/null)
  fi
fi
[ -z "$ARCHETYPE" ] && ARCHETYPE="unknown"

# === Stopword filtering ===
# Short list; bash-discipline.md compatible (no associative array — case statement).
# Phase 7.2.3 (2026-05-21): added five high-frequency low-signal generics from corpus
# analysis (use=52% of descriptions, skill=19% self-reference, any/should/before/well
# 8% each). These tokens never differentiate skills — stripping them from query
# tokenization eliminates a class of false-positive Pool 2 matches.
STOPWORDS="a an the of for to in on with and or is are was were be been being do does did how what when where why which who that this these those i me my you your it its at by as from use skill any should before"

is_stopword() {
  local w="$1"
  for sw in $STOPWORDS; do
    [ "$w" = "$sw" ] && return 0
  done
  return 1
}

# Tokenize query: lowercase, split on non-alpha, strip stopwords, keep ≥3 chars
QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' ' ')
KEYWORDS=""
for tok in $QUERY_LOWER; do
  [ ${#tok} -lt 3 ] && continue
  if ! is_stopword "$tok"; then
    KEYWORDS="$KEYWORDS $tok"
  fi
done
KEYWORDS=$(echo "$KEYWORDS" | xargs)

# All-stopword / too-short-only queries (KEYWORDS empty after filtering) — same UX as empty.
if [ -z "$KEYWORDS" ]; then
  echo "# Empty query — usage: /skills 'what you want to do'"
  exit 0
fi

# === Pool 1: archetype-relevant from manifest ===
POOL1=""
if [ -f "$MANIFEST" ]; then
  ARCH_ESCAPED=$(printf '%s' "$ARCHETYPE" | sed 's/[][\\.*+?(){}|^$]/\\&/g')
  while IFS= read -r line; do
    case "$line" in ""|\#*) continue ;; esac
    SNAME=$(echo "$line" | sed -E 's/^"([^"]+)":.*/\1/')
    SARCHS=$(echo "$line" | sed -E 's/^"[^"]+":[[:space:]]*\[([^][]+)\].*/\1/')
    if echo "$SARCHS" | grep -qE "(^|[, ])($ARCH_ESCAPED|always-on)([,[:space:]]|$)"; then
      # Phase 7.4: drop eliminated skills here too. Pool 1 feeds Tier B
      # (alphabetical archetype fallback); without this filter, eliminated
      # always-on skills would still surface via the Tier B path even after
      # being filtered out of Pool 2.
      is_eliminated "$SNAME" && continue
      POOL1="$POOL1
$SNAME|$SARCHS"
    fi
  done < "$MANIFEST"
fi

# === Pool 2: keyword grep across all SKILL.md files ===
POOL2_FILES=""
if [ -n "$KEYWORDS" ]; then
  # Build a single grep alternation: keyword1|keyword2|...
  GREP_ALT=$(echo "$KEYWORDS" | tr ' ' '|')
  # Personal skills
  while IFS= read -r f; do
    [ -f "$f" ] && POOL2_FILES="$POOL2_FILES
$f"
  done < <(grep -rli -E "\\b($GREP_ALT)\\b" "$PERSONAL_SKILLS_DIR"/*/SKILL.md 2>/dev/null)
  # Plugin skills
  while IFS= read -r f; do
    [ -f "$f" ] && POOL2_FILES="$POOL2_FILES
$f"
  done < <(grep -rli -E "\\b($GREP_ALT)\\b" "$PLUGIN_CACHE_DIR"/*/*/*/skills/*/SKILL.md 2>/dev/null)
fi

# Phase 7.2.1: compute Pool 2 score (distinct keywords matched in description).
# Whole-file grep includes body noise (example prompts, instructions) that don't
# reflect the skill's purpose. Score against the description line only.
#
# Phase 7.2.2: Pool 2 *membership* also requires description-line keyword match
# (score ≥ 1) — see filter at end of POOL2 construction loop below. Whole-file
# grep stays as a cheap prefilter to narrow the candidate set before scoring;
# score=0 candidates are dropped so they don't crowd Tier A (Pool 1 ∩ Pool 2)
# with body-only matches that displace true semantic matches in Tier C.
#
# Phase 7.2.3: stemming pattern tightened from `\b<kw>` (unbounded prefix) to
# `\b<kw>(s|es|d|ed|ing)?\b` (controlled regular-suffix stems with trailing
# word-boundary). The unbounded prefix had a false-positive class: `\bmake`
# matched `maker` in literal strings like "decision-maker", scoring keywords
# that didn't reflect skill purpose. The tightened pattern still catches
# regular stems (write/writes/writing, caption/captions/captioning, debug/
# debugging) — covers the dominant skill-description vocabulary — while
# refusing the within-word false positives. Irregular stems (made, wrote,
# written, did) are intentionally NOT covered; queries with those forms are
# rare and the cost of including all English irregulars exceeds the benefit.
compute_score() {
  local f="$1"
  local desc
  desc=$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit}' "$f" 2>/dev/null)
  local s=0
  for kw in $KEYWORDS; do
    if echo "$desc" | grep -qiE "\\b$kw(s|es|d|ed|ing)?\\b" 2>/dev/null; then
      s=$((s + 1))
    fi
  done
  echo "$s"
}

# Convert POOL2_FILES → POOL2 with name + archetype + score (3 columns: name|archs|score)
POOL2=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ ! -f "$f" ] && continue
  # Derive skill name:
  # - Personal: ~/.claude/skills/<name>/SKILL.md → <name>
  # - Plugin:   ~/.claude/plugins/cache/<mp>/<plugin>/<ver>/skills/<base>/SKILL.md → <plugin>:<base>
  case "$f" in
    "$PERSONAL_SKILLS_DIR"/*)
      SNAME=$(echo "$f" | sed "s|^$PERSONAL_SKILLS_DIR/||; s|/SKILL.md$||")
      ;;
    "$PLUGIN_CACHE_DIR"/*)
      # Extract <plugin> and <base> from the path
      REL=${f#$PLUGIN_CACHE_DIR/}
      PLUG=$(echo "$REL" | awk -F/ '{print $2}')
      BASE=$(echo "$REL" | sed -E 's|^[^/]+/[^/]+/[^/]+/skills/([^/]+)/SKILL.md$|\1|')
      SNAME="$PLUG:$BASE"
      ;;
    *)
      continue
      ;;
  esac
  # Look up archetypes from manifest (may be empty)
  SARCHS_RAW=$(grep -E "^\"$SNAME\":" "$MANIFEST" 2>/dev/null | sed -E 's/^"[^"]+":[[:space:]]*\[([^][]+)\].*/\1/')
  if [ -z "$SARCHS_RAW" ]; then
    SARCHS_RAW="(none)"
  fi
  # Phase 7.2.1: compute distinct-keyword-match score for this file
  SCORE=$(compute_score "$f")
  # Phase 7.2.2: drop body-only matches (score=0). Description carries the
  # skill's purpose; body matches are noise (examples / instructions / triggers
  # that happen to mention a keyword without making the skill relevant).
  [ "$SCORE" = "0" ] && continue
  # Phase 7.4: drop skills the user has consistently rejected via /bake-off
  # (≥3 appearances + 0 wins). Kill switch: BAKEOFF_ELIMINATE=off.
  is_eliminated "$SNAME" && continue
  POOL2="$POOL2
$SNAME|$SARCHS_RAW|$SCORE"
done <<< "$POOL2_FILES"

# Pool 2 empty after keyword grep → no semantic match. Pool 1 always populates
# (always-on skills match unconditionally), so it's not a meaningful "match" signal.
P2_CHECK=$(echo "$POOL2" | awk -F'|' '$1!="" {print}' | head -1)
if [ -z "$P2_CHECK" ]; then
  echo "# No matches found — try broadening your query"
  exit 0
fi

# === Combine + dedupe + tier sort + cap ===
# Tier A: Pool 1 ∩ Pool 2 (in both — strongest signal)
# Tier C: Pool 2 only (semantic match — query-relevant)
# Tier B: Pool 1 only (archetype-relevant context)
# Within each tier: alphabetical by name. Cap total at 30.
# (Pool 2 ranks above Pool 1-only because the user's query is the strongest relevance signal.)

# Helper: extract names (column 1)
names_in() {
  echo "$1" | awk -F'|' '$1!="" {print $1}' | sort -u
}

P1_NAMES=$(names_in "$POOL1")
P2_NAMES=$(names_in "$POOL2")

TIER_A=""
TIER_B=""
TIER_C=""

# Tier A: in both
while IFS= read -r n; do
  [ -z "$n" ] && continue
  if echo "$P2_NAMES" | grep -qx "$n"; then
    TIER_A="$TIER_A
$n"
  fi
done <<< "$P1_NAMES"

# Tier B: P1 not in P2
while IFS= read -r n; do
  [ -z "$n" ] && continue
  if ! echo "$P2_NAMES" | grep -qx "$n"; then
    TIER_B="$TIER_B
$n"
  fi
done <<< "$P1_NAMES"

# Tier C: P2 not in P1
while IFS= read -r n; do
  [ -z "$n" ] && continue
  if ! echo "$P1_NAMES" | grep -qx "$n"; then
    TIER_C="$TIER_C
$n"
  fi
done <<< "$P2_NAMES"

# Phase 7.2.1: lookup helper — Pool 2 score for a given name (0 if absent)
score_for() {
  local n="$1"
  local s
  s=$(echo "$POOL2" | awk -F'|' -v n="$n" '$1==n {print $3; exit}')
  [ -z "$s" ] && s=0
  echo "$s"
}

# Phase 7.2.1: sort by Pool 2 score DESC, then alphabetical within score band.
# Used for Tier A and Tier C (both have Pool 2 scoring data).
sort_by_score() {
  local list="$1"
  local n s
  echo "$list" | grep -v '^$' | sort -u | while IFS= read -r n; do
    [ -z "$n" ] && continue
    s=$(score_for "$n")
    printf '%s|%s\n' "$s" "$n"
  done | sort -t'|' -k1,1nr -k2,2 | awk -F'|' '{print $2}'
}

# Tier A and Tier C have Pool 2 scoring data — sort by score desc, then alpha.
# Tier B (Pool 1 only) didn't match keywords — alpha sort only.
TIER_A=$(sort_by_score "$TIER_A")
TIER_C=$(sort_by_score "$TIER_C")
TIER_B=$(echo "$TIER_B" | grep -v '^$' | sort -u)

# Build ordered name list, cap at 30
ORDERED=$(printf '%s\n%s\n%s\n' "$TIER_A" "$TIER_C" "$TIER_B" | grep -v '^$' | head -30)

TOTAL_BEFORE_CAP=$(printf '%s\n%s\n%s\n' "$TIER_A" "$TIER_C" "$TIER_B" | grep -v '^$' | wc -l | tr -d ' ')

# No matches sentinel
if [ -z "$ORDERED" ]; then
  echo "# No matches found — try broadening your query"
  exit 0
fi

# Helper: get archetypes for a name (prefer Pool 1's value; fall back to Pool 2's)
arch_for() {
  local n="$1"
  local v
  v=$(echo "$POOL1" | awk -F'|' -v n="$n" '$1==n {print $2; exit}')
  if [ -z "$v" ]; then
    v=$(echo "$POOL2" | awk -F'|' -v n="$n" '$1==n {print $2; exit}')
  fi
  [ -z "$v" ] && v="(none)"
  echo "$v"
}

# Helper: get description excerpt from SKILL.md (60 chars)
desc_for() {
  local n="$1"
  local f
  if [ "${n#*:}" = "$n" ]; then
    f="$PERSONAL_SKILLS_DIR/$n/SKILL.md"
  else
    local plug="${n%%:*}"
    local base="${n#*:}"
    f=$(find "$PLUGIN_CACHE_DIR"/*/"$plug" -path "*/skills/$base/SKILL.md" 2>/dev/null | head -1)
  fi
  if [ -n "$f" ] && [ -f "$f" ]; then
    awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit}' "$f" 2>/dev/null | cut -c1-60
  fi
}

# Header
echo "# Candidates ($TOTAL_BEFORE_CAP total, showing $(echo "$ORDERED" | wc -l | tr -d ' ')):"

# Emit (Phase 7.4: column 4 = "untried" if appearances<3, else empty.
# The literal flag is consumed by the /skills slash command body, which
# prefixes "✨ " to the displayed name. Column 1 stays a clean name so
# downstream consumers like bake-off-prefilter.sh:50 can use it for
# stats lookups without prefix-stripping.)
while IFS= read -r n; do
  [ -z "$n" ] && continue
  A=$(arch_for "$n")
  D=$(desc_for "$n")
  UNTRIED=""
  is_untried "$n" && UNTRIED="untried"
  echo "$n|$A|$D|$UNTRIED"
done <<< "$ORDERED"

exit 0
