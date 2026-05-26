#!/usr/bin/env bash
set +e
# Placeholder: no classifier exists in RED. Assert FALSE so this fails until implemented.
# Expected real shape: given prompt "fix typo" with manifest default_scope=L for the matched JTBD,
# the classifier MUST return S (prompt-based override of declared scope).
PASS=0; FAIL=0

CLASSIFIER="$HOME/.claude/scripts/classify-scope.sh"
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: classify-scope.sh not found (placeholder fail in RED)"; FAIL=$((FAIL+1))
else
  RESULT=$("$CLASSIFIER" --prompt "fix typo" --jtbd-default L 2>&1)
  if [ "$RESULT" = "S" ]; then
    echo "PASS: classifier returns S for 'fix typo' overriding L"; PASS=$((PASS+1))
  else
    echo "FAIL: got '$RESULT' (expected S)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
