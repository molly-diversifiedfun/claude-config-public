#!/usr/bin/env bash
# bake-off-record.sh — atomic recorder for /bake-off
# Args: <mode> <query> <result-json> <a> <b> <c> <archetype>   (EXACTLY 7 args; empty strings OK)
# Where result-json is a JSON object: {"kind":"winner","winner_idx":0}
#                                  or {"kind":"yolo_rating","yolo_rating":"worked"}
#                                  or {"kind":"tie"} | {"kind":"none_worked"} | {"kind":"skip"}
#
# winner_idx is a ZERO-BASED index into candidates[a, b, c] (so winner_idx=0 means
# slot A, winner_idx=2 means slot C). This convention is also what bake-off-log.jsonl
# records — any reader/parser must use zero-based indexing or stats reconstruction
# from the JSONL will be wrong.
#
# Exit 0 success, 2 bad args, 3 lock timeout, 4 disk full
#
# Env vars (for test isolation, default to live paths under $HOME/.claude/data):
#   BAKEOFF_STATS_FILE  — overrides STATS_TSV
#   BAKEOFF_LOG_FILE    — overrides LOG_JSONL
#   BAKEOFF_LOCK_DIR    — overrides LOCK_DIR (default: <stats-file-dir>/.bake-off.lock.d)
# Tests should always set BAKEOFF_STATS_FILE + BAKEOFF_LOG_FILE to mktemp -d paths
# so the live stats file is never touched (per
# feedback_test_fixtures_must_not_write_live_data_files.md).

set +e

STATS_TSV="${BAKEOFF_STATS_FILE:-$HOME/.claude/data/bake-off-stats.tsv}"
LOG_JSONL="${BAKEOFF_LOG_FILE:-$HOME/.claude/data/bake-off-log.jsonl}"
LOCK_DIR="${BAKEOFF_LOCK_DIR:-$(dirname "$STATS_TSV")/.bake-off.lock.d}"
WARN_LOG="$HOME/.claude/logs/bake-off-warnings.log"
mkdir -p "$(dirname "$STATS_TSV")" "$(dirname "$LOG_JSONL")" "$HOME/.claude/logs"

# === mkdir-based lock (POSIX-atomic, no flock dependency) ===
# Polls at 0.1s intervals (macOS sleep handles fractional seconds). 5s total
# budget = 50 poll attempts. At ~0.17s per held lock, even 10 parallel callers
# fully serialize in ~2s — well within budget.
acquire_lock() {
  local max_iters=50  # 50 × 0.1s = 5s total budget
  local iters=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 0.1
    iters=$((iters + 1))
    if [ "$iters" -ge "$max_iters" ]; then
      return 1
    fi
  done
  return 0
}
release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null
}

# Kill switch — no-op
if [ "${BAKEOFF:-on}" = "off" ]; then
  exit 0
fi

# Last positional arg is archetype; everything between $4 and $(end-1) is candidate names.
# Signatures by mode:
#   yolo1:    <mode> <query> <result-json> <a>           <archetype>   = 5 args
#   control2: <mode> <query> <result-json> <a> <b>       <archetype>   = 6 args
#   blind3:   <mode> <query> <result-json> <a> <b> <c>   <archetype>   = 7 args
# To keep the wrapper simple, callers MUST pass exactly 7 args with empty strings
# for unused slots: <mode> <query> <result-json> <a> <b> <c> <archetype>
if [ "$#" -ne 7 ]; then
  echo "bake-off-record: expected 7 args (mode query result-json a b c archetype), got $#" >&2
  exit 2
fi

MODE="$1"
QUERY="$2"
RESULT_JSON="$3"
A="$4"
B="$5"
C="$6"
ARCHETYPE="$7"
TS="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# === Build candidates JSON array ===
build_candidates_json() {
  local out="["
  local first=1
  for name in "$A" "$B" "$C"; do
    [ -z "$name" ] && continue
    # JSON-escape: only " and \ matter for skill names (no newlines, no control chars in practice)
    local esc; esc=$(printf '%s' "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    [ $first -eq 1 ] && first=0 || out="$out,"
    out="$out\"$esc\""
  done
  out="$out]"
  echo "$out"
}

# === Escape arbitrary string for JSON ===
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//'
}

CANDIDATES_JSON=$(build_candidates_json)
QUERY_ESC=$(json_escape "$QUERY")
ARCH_ESC=$(json_escape "$ARCHETYPE")

# === Append jsonl (line-atomic on POSIX <PIPE_BUF) ===
LINE="{\"ts\":\"$TS\",\"mode\":\"$MODE\",\"query\":\"$QUERY_ESC\",\"archetype\":\"$ARCH_ESC\",\"candidates\":$CANDIDATES_JSON,\"result\":$RESULT_JSON}"
if ! echo "$LINE" >> "$LOG_JSONL"; then
  echo "bake-off-record: jsonl append failed (disk full?)" >&2
  exit 4
fi

# === Determine per-skill deltas from RESULT_JSON ===
# Returns: appearances_delta wins_delta losses_delta  for the given slot ("A"/"B"/"C") and current MODE.
deltas_for_slot() {
  local slot="$1"  # "A" "B" "C"
  local kind; kind=$(echo "$RESULT_JSON" | sed -n 's/.*"kind":"\([^"]*\)".*/\1/p')
  local widx; widx=$(echo "$RESULT_JSON" | sed -n 's/.*"winner_idx":\([0-9]*\).*/\1/p')
  local yrate; yrate=$(echo "$RESULT_JSON" | sed -n 's/.*"yolo_rating":"\([^"]*\)".*/\1/p')

  case "$kind" in
    winner)
      # idx 0 = A, 1 = B, 2 = C; this slot won iff matches widx
      local sidx
      case "$slot" in A) sidx=0;; B) sidx=1;; C) sidx=2;; esac
      if [ "$sidx" = "$widx" ]; then
        echo "1 1 0"
      else
        echo "1 0 1"
      fi
      ;;
    yolo_rating)
      case "$yrate" in
        worked)  echo "1 1 0" ;;
        nope)    echo "1 0 1" ;;
        partial) echo "1 0 0" ;;
        *)       echo "1 0 0" ;;
      esac
      ;;
    none_worked)
      echo "1 0 1"  # loss for every slot
      ;;
    tie|skip|*)
      echo "1 0 0"  # appearance only
      ;;
  esac
}

# === Update tsv (caller already holds the mkdir lock) ===
update_tsv() {
  local skill="$1"
  [ -z "$skill" ] && return
  local slot="$2"
  local d; d=$(deltas_for_slot "$slot")
  local dapp dwins dlosses
  dapp=$(echo "$d" | awk '{print $1}')
  dwins=$(echo "$d" | awk '{print $2}')
  dlosses=$(echo "$d" | awk '{print $3}')

  # Read current row (if any)
  local cur_app=0 cur_wins=0 cur_losses=0
  if [ -f "$STATS_TSV" ]; then
    local row; row=$(awk -F'\t' -v s="$skill" 'NR>1 && $1==s' "$STATS_TSV")
    if [ -n "$row" ]; then
      cur_app=$(echo "$row" | awk -F'\t' '{print $2}')
      cur_wins=$(echo "$row" | awk -F'\t' '{print $3}')
      cur_losses=$(echo "$row" | awk -F'\t' '{print $4}')
    fi
  fi

  local new_app=$((cur_app + dapp))
  local new_wins=$((cur_wins + dwins))
  local new_losses=$((cur_losses + dlosses))

  # Rewrite tsv: header + all rows except this skill + this skill's new row
  local tmp; tmp=$(mktemp)
  if [ ! -f "$STATS_TSV" ]; then
    printf 'skill_name\tappearances\twins\tlosses\tlast_run_iso\n' > "$tmp"
  else
    awk -F'\t' -v s="$skill" 'NR==1 || $1!=s' "$STATS_TSV" > "$tmp"
  fi
  printf '%s\t%d\t%d\t%d\t%s\n' "$skill" "$new_app" "$new_wins" "$new_losses" "$TS" >> "$tmp"
  mv "$tmp" "$STATS_TSV"
}

# Acquire mkdir-based lock with 5s timeout
if ! acquire_lock; then
  echo "{\"ts\":\"$TS\",\"event\":\"lock_timeout\",\"skill_a\":\"$A\"}" >> "$WARN_LOG"
  echo "bake-off-record: lock timeout" >&2
  exit 3
fi

# Ensure lock is released even on error
trap release_lock EXIT

[ -n "$A" ] && update_tsv "$A" "A"
[ -n "$B" ] && update_tsv "$B" "B"
[ -n "$C" ] && update_tsv "$C" "C"

release_lock
trap - EXIT
exit 0
