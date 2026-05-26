#!/usr/bin/env bash
set +e
MANIFEST="$HOME/.claude/agent-skill-manifest.yaml"
PASS=0; FAIL=0

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: production manifest not found at $MANIFEST"; FAIL=$((FAIL+1))
else
  OWNER=$(MANIFEST_PATH="$MANIFEST" python3 - <<'PYEOF'
import os, sys
try:
    import yaml
except ImportError:
    print("NO_YAML"); sys.exit(0)
data = yaml.safe_load(open(os.environ['MANIFEST_PATH']))
for name, agent in (data.get('agents') or {}).items():
    if '/fix' in (agent.get('owns_slash_commands') or []):
        print(name); sys.exit(0)
print("NONE")
PYEOF
)
  if [ "$OWNER" = "builder" ]; then
    echo "PASS: /fix owned by builder"; PASS=$((PASS+1))
  else
    echo "FAIL: /fix owner is '$OWNER' (expected builder)"; FAIL=$((FAIL+1))
  fi
fi
echo "Summary: $PASS pass / $FAIL fail"
[ "$FAIL" -eq 0 ]
