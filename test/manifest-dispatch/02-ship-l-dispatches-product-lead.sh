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
for j in (data.get('jtbd') or []):
    if j.get('id') == 'ship-a-feature':
        specs = j.get('specialists') or []
        scope = j.get('default_scope')
        has_pl = 'product-lead' in specs
        print(f"specs_has_pl={has_pl} scope={scope}")
        sys.exit(0)
print("NOT_FOUND")
PYEOF
)
  if echo "$RESULT" | grep -q "specs_has_pl=True scope=M"; then
    echo "PASS: ship-a-feature has product-lead specialist + default_scope=M"; PASS=$((PASS+1))
  else
    echo "FAIL: got '$RESULT'"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
