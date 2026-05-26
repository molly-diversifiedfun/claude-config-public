#!/usr/bin/env bash
set +e
# Placeholder: no classifier exists in RED. Assert FALSE so this fails until implemented.
# Expected real shape: given prompt "add an env var" matching a JTBD with default_scope=S,
# the classifier MUST return S.
PASS=0; FAIL=0

CLASSIFIER="$HOME/.claude/scripts/classify-scope.sh"
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classify-scope.sh not found (placeholder fail in RED)"; FAIL=$((FAIL+1))
else
  RESULT=$("$CLASSIFIER" --prompt "add an env var" --jtbd-default S 2>&1)
  if [ "$RESULT" = "S" ]; then
    echo "PASS: classifier returns S for 'add an env var' matching JTBD default S"; PASS=$((PASS+1))
  else
    echo "FAIL: got '$RESULT' (expected S)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
