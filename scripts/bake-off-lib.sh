#!/usr/bin/env bash
# bake-off-lib.sh — shared stats-file helpers for skills-prefilter.sh + bake-off-prefilter.sh.
# Sourced, not executed: `. "$(dirname "$0")/bake-off-lib.sh"`
#
# All functions default to "skill is fine" semantics on missing/malformed data:
#   - missing row → 0 appearances → untried + not eliminated
#   - missing file → same
#   - malformed row → awk skips it; no error surfaced
#
# Kill switch: BAKEOFF_ELIMINATE=off forces is_eliminated to always return false.
# Stats file path overridable via BAKEOFF_STATS_FILE (used by unit tests via mktemp -d).

_bakeoff_stats_file() {
  printf '%s' "${BAKEOFF_STATS_FILE:-$HOME/.claude/data/bake-off-stats.tsv}"
}

# stdout: integer (0 if no row, no file, or malformed)
appearances_of() {
  local skill="$1"
  local file; file=$(_bakeoff_stats_file)
  [ -f "$file" ] || { echo 0; return; }
  local v
  v=$(awk -F'\t' -v s="$skill" 'NR>1 && $1==s {print $2; exit}' "$file" 2>/dev/null)
  printf '%d\n' "${v:-0}" 2>/dev/null || echo 0
}

# stdout: integer (0 if no row, no file, or malformed)
wins_of() {
  local skill="$1"
  local file; file=$(_bakeoff_stats_file)
  [ -f "$file" ] || { echo 0; return; }
  local v
  v=$(awk -F'\t' -v s="$skill" 'NR>1 && $1==s {print $3; exit}' "$file" 2>/dev/null)
  printf '%d\n' "${v:-0}" 2>/dev/null || echo 0
}

# stdout: integer (0 if no row, no file, or malformed)
losses_of() {
  local skill="$1"
  local file; file=$(_bakeoff_stats_file)
  [ -f "$file" ] || { echo 0; return; }
  local v
  v=$(awk -F'\t' -v s="$skill" 'NR>1 && $1==s {print $4; exit}' "$file" 2>/dev/null)
  printf '%d\n' "${v:-0}" 2>/dev/null || echo 0
}

# exit 0 (true) if appearances < 3; else exit 1.
# Skills with no row → 0 appearances → untried.
is_untried() {
  local apps; apps=$(appearances_of "$1")
  [ "$apps" -lt 3 ]
}

# exit 0 (true) if appearances ≥ 3 AND wins == 0; else exit 1.
# Kill switch: BAKEOFF_ELIMINATE=off forces false.
is_eliminated() {
  [ "${BAKEOFF_ELIMINATE:-on}" = "off" ] && return 1
  local apps wins
  apps=$(appearances_of "$1")
  wins=$(wins_of "$1")
  [ "$apps" -ge 3 ] && [ "$wins" -eq 0 ]
}
