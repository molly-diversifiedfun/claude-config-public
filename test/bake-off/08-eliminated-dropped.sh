#!/usr/bin/env bash
# Test: Phase 7.4 — bake-off-prefilter.sh end-to-end drops eliminated skills.
# Validates the integration: with a stats fixture eliminating a skill, the
# bake-off-prefilter must not return that skill in any slot.
#
# Note on scope: skills-prefilter (Phase 7.4) ALREADY drops eliminated skills
# from its output, so by the time bake-off-prefilter sees CANDIDATES, eliminated
# skills are already gone. This test verifies the end-to-end pipeline behaves
# correctly — it does NOT isolate bake-off-prefilter's own is_eliminated guards
# (those are defense-in-depth, validated by code review + the lib unit tests).
#
# Per-mode stochastic testing (30 invocations of yolo1/control2) was dropped
# because (a) skills-prefilter is ~10s per call → 10+ min suite, and (b) the
# eliminated skill is unreachable through that path anyway. blind3 (deterministic,
# 3 picks) gives sufficient integration signal.
#
# Fixture strategy: mktemp -d + BAKEOFF_STATS_FILE override (per
# feedback_test_fixtures_must_not_write_live_data_files.md) — NEVER touches
# the live ~/.claude/data/bake-off-stats.tsv file.
set +e

SCRIPT="$HOME/.claude/scripts/bake-off-prefilter.sh"
PASS=0; FAIL=0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture: humanize-ai-writing eliminated (3 apps, 0 wins).
cat > "$TMPDIR/stats.tsv" <<'EOF'
skill_name	appearances	wins	losses	last_run_iso
humanize-ai-writing	3	0	3	2026-05-21T00:00:00Z
EOF

export BAKEOFF_STATS_FILE="$TMPDIR/stats.tsv"
cd ~/github

# Assertion 1: blind3 mode — eliminated skill not in any of A/B/C slots
BLIND_OUT=$(bash "$SCRIPT" "humanize paragraph less" 2>&1)
BLIND_LINE=$(echo "$BLIND_OUT" | grep -E '^blind3\|' | head -1)
if [ -z "$BLIND_LINE" ]; then
  echo "FAIL: blind3 produced no candidate line. Output: $BLIND_OUT"
  FAIL=$((FAIL+1))
else
  A=$(echo "$BLIND_LINE" | awk -F'|' '{print $2}')
  B=$(echo "$BLIND_LINE" | awk -F'|' '{print $3}')
  C=$(echo "$BLIND_LINE" | awk -F'|' '{print $4}')
  HIT=""
  for slot in "$A" "$B" "$C"; do
    [ "$slot" = "humanize-ai-writing" ] && HIT=1
  done
  if [ -n "$HIT" ]; then
    echo "FAIL: blind3 picked eliminated humanize-ai-writing (A=$A B=$B C=$C)"
    FAIL=$((FAIL+1))
  else
    echo "PASS: blind3 dropped eliminated skill (A=$A B=$B C=$C)"
    PASS=$((PASS+1))
  fi
fi

# Assertion 2: yolo1 mode runs without error and returns a non-eliminated skill
YOLO_OUT=$(bash "$SCRIPT" "--yolo humanize paragraph less" 2>&1)
YOLO_LINE=$(echo "$YOLO_OUT" | grep -E '^yolo1\|' | head -1)
if [ -z "$YOLO_LINE" ]; then
  echo "FAIL: yolo1 produced no candidate line. Output: $YOLO_OUT"
  FAIL=$((FAIL+1))
elif [ "$(echo "$YOLO_LINE" | awk -F'|' '{print $2}')" = "humanize-ai-writing" ]; then
  echo "FAIL: yolo1 picked eliminated humanize-ai-writing"
  FAIL=$((FAIL+1))
else
  PICK=$(echo "$YOLO_LINE" | awk -F'|' '{print $2}')
  echo "PASS: yolo1 returned non-eliminated skill ($PICK)"
  PASS=$((PASS+1))
fi

# Assertion 3: control2 mode runs without error and returns non-eliminated skills
CTRL_OUT=$(bash "$SCRIPT" "--control humanize paragraph less" 2>&1)
CTRL_LINE=$(echo "$CTRL_OUT" | grep -E '^control2\|' | head -1)
if [ -z "$CTRL_LINE" ]; then
  echo "FAIL: control2 produced no candidate line. Output: $CTRL_OUT"
  FAIL=$((FAIL+1))
else
  KG=$(echo "$CTRL_LINE" | awk -F'|' '{print $2}')
  YO=$(echo "$CTRL_LINE" | awk -F'|' '{print $3}')
  if [ "$KG" = "humanize-ai-writing" ] || [ "$YO" = "humanize-ai-writing" ]; then
    echo "FAIL: control2 picked eliminated humanize-ai-writing (KG=$KG YOLO=$YO)"
    FAIL=$((FAIL+1))
  else
    echo "PASS: control2 returned non-eliminated skills (KG=$KG YOLO=$YO)"
    PASS=$((PASS+1))
  fi
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
