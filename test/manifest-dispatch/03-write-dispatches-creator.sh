#!/usr/bin/env bash
set +e
MANIFEST="$HOME/.claude/agent-skill-manifest.yaml"
PASS=0; FAIL=0

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: production manifest not found at $MANIFEST"; FAIL=$((FAIL+1))
else
  HAS=$(MANIFEST_PATH="$MANIFEST" python3 - <<'PYEOF'
import os, sys
try:
    import yaml
except ImportError:
    print("NO_YAML"); sys.exit(0)
data = yaml.safe_load(open(os.environ['MANIFEST_PATH']))
creator = (data.get('agents') or {}).get('creator') or {}
cmds = creator.get('owns_slash_commands') or []
print("YES" if "/write" in cmds else "NO")
PYEOF
)
  if [ "$HAS" = "YES" ]; then
    echo "PASS: /write owned by creator"; PASS=$((PASS+1))
  else
    echo "FAIL: /write not in creator.owns_slash_commands (got '$HAS')"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
