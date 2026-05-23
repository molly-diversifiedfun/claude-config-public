#!/usr/bin/env bash
# 01-prefilter-modes.sh — flag parsing + mode-specific slot emission
set +e

SCRIPT="$HOME/.claude/scripts/bake-off-prefilter.sh"
PASS=0; FAIL=0

assert_emits() {
  local label="$1" input="$2" expected_mode="$3"
  local out; out=$(bash "$SCRIPT" "$input" 2>&1)
  local first_data_line; first_data_line=$(echo "$out" | grep -v '^#' | head -1)
  local actual_mode; actual_mode=$(echo "$first_data_line" | cut -d'|' -f1)
  if [ "$actual_mode" = "$expected_mode" ]; then
    echo "PASS: $label"; PASS=$((PASS+1))
  else
    echo "FAIL: $label (expected mode=$expected_mode, got first line: $first_data_line)"
    FAIL=$((FAIL+1))
  fi
}

assert_sentinel() {
  local label="$1" input="$2" needle="$3"
  local out; out=$(bash "$SCRIPT" "$input" 2>&1)
  if echo "$out" | grep -q "$needle"; then
    echo "PASS: $label"; PASS=$((PASS+1))
  else
    echo "FAIL: $label (expected sentinel containing '$needle', got: $out)"
    FAIL=$((FAIL+1))
  fi
}

assert_emits "blind3 default mode (no flag)" "audit hook safety" "blind3"
assert_emits "yolo1 with --yolo flag" "--yolo audit hook safety" "yolo1"
assert_emits "control2 with --control flag" "--control audit hook safety" "control2"
assert_sentinel "unknown flag emits sentinel" "--bogus audit hook safety" "Unknown mode"
assert_sentinel "empty query emits usage" "" "Empty query"

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
