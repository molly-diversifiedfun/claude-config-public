#!/bin/bash
# Mocked claude returns valid JSON but with scope outside enum; classifier soft-fails to S.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/claude" <<'EOF'
#!/bin/bash
INNER='{"scope":"HUGE","rationale":"made-up tier"}'
printf '{"type":"result","result":%s}\n' "$(echo "$INNER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
EOF
chmod +x "$TMP/claude"

OUT=$(SHIP_SCOPE_CLAUDE_CMD="$TMP/claude" python3 ~/.claude/scripts/ship-scope-classify.py "x")
echo "$OUT" | grep -q '"scope": "S"' || { echo "expected S fallback: $OUT"; exit 1; }
echo "$OUT" | grep -q "invalid scope" || { echo "expected invalid-scope rationale: $OUT"; exit 1; }
echo "04-invalid-scope-rejected: OK"
