#!/usr/bin/env bash
# 06-kill-switch.sh — BAKEOFF=off sentinels prefilter; no-ops recorder
set +e

PREFILTER="$HOME/.claude/scripts/bake-off-prefilter.sh"
RECORDER="$HOME/.claude/scripts/bake-off-record.sh"
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

# Prefilter with kill switch
OUT=$(BAKEOFF=off bash "$PREFILTER" "audit hook safety" 2>&1)
if echo "$OUT" | grep -q "Bake-off disabled"; then
  echo "PASS: prefilter sentinel under BAKEOFF=off"; PASS=$((PASS+1))
else
  echo "FAIL: expected 'Bake-off disabled' sentinel, got: $OUT"; FAIL=$((FAIL+1))
fi

# Recorder with kill switch — must NOT write
BAKEOFF=off bash "$RECORDER" "yolo1" "q" '{"kind":"yolo_rating","yolo_rating":"worked"}' "killtest" "" "" "arch"
EXIT=$?
if [ "$EXIT" = "0" ] && [ ! -f "$LOG_JSONL" ]; then
  echo "PASS: recorder no-op under BAKEOFF=off (no jsonl written, exit 0)"; PASS=$((PASS+1))
else
  echo "FAIL: recorder should be no-op under BAKEOFF=off (exit=$EXIT, jsonl exists=$( [ -f "$LOG_JSONL" ] && echo yes || echo no))"
  FAIL=$((FAIL+1))
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
