#!/usr/bin/env bash
# 04-recorder-atomicity.sh — 10 parallel recorder calls produce 10 jsonl lines, tallies intact
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

# Fire 10 parallel yolo1 "worked" recordings on the SAME skill
for i in $(seq 1 10); do
  bash "$SCRIPT" "yolo1" "test query $i" '{"kind":"yolo_rating","yolo_rating":"worked"}' "testskill" "" "" "testarch" &
done
wait

# Verify jsonl line count
LINE_COUNT=$(wc -l < "$LOG_JSONL" | tr -d ' ')
if [ "$LINE_COUNT" = "10" ]; then
  echo "PASS: jsonl has 10 lines"; PASS=$((PASS+1))
else
  echo "FAIL: jsonl expected 10 lines, got $LINE_COUNT"; FAIL=$((FAIL+1))
fi

# Verify tally row exists with appearances=10, wins=10, losses=0
ROW=$(awk -F'\t' 'NR>1 && $1=="testskill"' "$STATS_TSV")
APP=$(echo "$ROW" | awk -F'\t' '{print $2}')
WINS=$(echo "$ROW" | awk -F'\t' '{print $3}')
LOSSES=$(echo "$ROW" | awk -F'\t' '{print $4}')
if [ "$APP" = "10" ] && [ "$WINS" = "10" ] && [ "$LOSSES" = "0" ]; then
  echo "PASS: tally row testskill 10/10/0"; PASS=$((PASS+1))
else
  echo "FAIL: tally row expected 10/10/0, got APP=$APP WINS=$WINS LOSSES=$LOSSES"; FAIL=$((FAIL+1))
fi

# Verify each jsonl line is well-formed JSON (at minimum: starts {"ts":")
# Note: grep -vc exits 1 when count is 0, so we capture stdout independently of exit.
BAD=$(grep -vc '^{"ts":"' "$LOG_JSONL" 2>/dev/null; true)
BAD=$(echo "$BAD" | head -1 | tr -d ' ')
if [ "$BAD" = "0" ]; then
  echo "PASS: all jsonl lines start with {\"ts\":\""; PASS=$((PASS+1))
else
  echo "FAIL: $BAD jsonl lines malformed"; FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
