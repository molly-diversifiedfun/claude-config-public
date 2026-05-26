#!/usr/bin/env bash
set +e
MANIFEST="$HOME/.claude/agent-skill-manifest.yaml"
PASS=0; FAIL=0

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: production manifest not found at $MANIFEST"; FAIL=$((FAIL+1))
else
  RESULT=$(MANIFEST_PATH="$MANIFEST" python3 - <<'PYEOF'
import os, sys
try:
    import yaml
except ImportError:
    print("NO_YAML"); sys.exit(0)
data = yaml.safe_load(open(os.environ['MANIFEST_PATH']))
designer = (data.get('agents') or {}).get('designer')
if not designer:
    print("MISSING"); sys.exit(0)
print(f"kind={designer.get('kind')} model={designer.get('model')}")
PYEOF
)
  if echo "$RESULT" | grep -q "kind=utility_specialist model=sonnet"; then
    echo "PASS: designer is utility_specialist + sonnet"; PASS=$((PASS+1))
  else
    echo "FAIL: got '$RESULT'"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
