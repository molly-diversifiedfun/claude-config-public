#!/usr/bin/env bash
# 05-recorder-mode-columns.sh — each mode×result updates the right tally columns
set +e

SCRIPT="$HOME/.claude/scripts/bake-off-record.sh"
PASS=0; FAIL=0

# Test isolation: mktemp -d + BAKEOFF_STATS_FILE/LOG_FILE override so the live
# stats + log files are NEVER touched (per
# feedback_test_fixtures_must_not_write_live_data_files.md).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"
export BAKEOFF_LOG_FILE="$TMPDIR/log.jsonl"
STATS_TSV="$BAKEOFF_STATS_FILE"
LOG_JSONL="$BAKEOFF_LOG_FILE"

row_for() {
  awk -F'\t' -v s="$1" 'NR>1 && $1==s' "$STATS_TSV"
}

assert_row() {
  local label="$1" skill="$2" exp_app="$3" exp_wins="$4" exp_losses="$5"
  local row; row=$(row_for "$skill")
  local app; app=$(echo "$row" | awk -F'\t' '{print $2}')
  local wins; wins=$(echo "$row" | awk -F'\t' '{print $3}')
  local losses; losses=$(echo "$row" | awk -F'\t' '{print $4}')
  if [ "$app" = "$exp_app" ] && [ "$wins" = "$exp_wins" ] && [ "$losses" = "$exp_losses" ]; then
    echo "PASS: $label ($skill $app/$wins/$losses)"; PASS=$((PASS+1))
  else
    echo "FAIL: $label expected $skill $exp_app/$exp_wins/$exp_losses, got $app/$wins/$losses"
    FAIL=$((FAIL+1))
  fi
}

# blind3 winner_idx=0 → A wins, B+C lose
bash "$SCRIPT" "blind3" "q" '{"kind":"winner","winner_idx":0}' "skA" "skB" "skC" "arch"
assert_row "blind3 winner" "skA" 1 1 0
assert_row "blind3 loser B" "skB" 1 0 1
assert_row "blind3 loser C" "skC" 1 0 1

# blind3 none_worked → all 3 lose
bash "$SCRIPT" "blind3" "q" '{"kind":"none_worked"}' "skD" "skE" "skF" "arch"
assert_row "blind3 none_worked D" "skD" 1 0 1
assert_row "blind3 none_worked E" "skE" 1 0 1
assert_row "blind3 none_worked F" "skF" 1 0 1

# yolo1 worked / partial / nope
bash "$SCRIPT" "yolo1" "q" '{"kind":"yolo_rating","yolo_rating":"worked"}' "skG" "" "" "arch"
bash "$SCRIPT" "yolo1" "q" '{"kind":"yolo_rating","yolo_rating":"partial"}' "skH" "" "" "arch"
bash "$SCRIPT" "yolo1" "q" '{"kind":"yolo_rating","yolo_rating":"nope"}' "skI" "" "" "arch"
assert_row "yolo worked" "skG" 1 1 0
assert_row "yolo partial" "skH" 1 0 0
assert_row "yolo nope" "skI" 1 0 1

# control2 winner_idx=1 → B wins, A loses
bash "$SCRIPT" "control2" "q" '{"kind":"winner","winner_idx":1}' "skJ" "skK" "" "arch"
assert_row "control2 winner B" "skK" 1 1 0
assert_row "control2 loser A" "skJ" 1 0 1

# control2 tie → both appearance only
bash "$SCRIPT" "control2" "q" '{"kind":"tie"}' "skL" "skM" "" "arch"
assert_row "control2 tie L" "skL" 1 0 0
assert_row "control2 tie M" "skM" 1 0 0

# control2 none_worked (the "Neither" vote) → both lose
bash "$SCRIPT" "control2" "q" '{"kind":"none_worked"}' "skN" "skO" "" "arch"
assert_row "control2 neither N" "skN" 1 0 1
assert_row "control2 neither O" "skO" 1 0 1

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
