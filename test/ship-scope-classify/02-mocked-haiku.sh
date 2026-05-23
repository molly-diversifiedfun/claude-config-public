#!/bin/bash
# Mocked claude returns valid JSON; classifier surfaces it cleanly.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/claude" <<'EOF'
#!/bin/bash
INNER='{"scope":"L","rationale":"multi-component refactor with migration"}'
printf '{"type":"result","result":%s}\n' "$(echo "$INNER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
EOF
chmod +x "$TMP/claude"

OUT=$(SHIP_SCOPE_CLAUDE_CMD="$TMP/claude" python3 ~/.claude/scripts/ship-scope-classify.py "rewrite the auth layer to use Supabase JWT")
echo "$OUT" | grep -q '"scope": "L"' || { echo "expected L: $OUT"; exit 1; }
echo "$OUT" | grep -q "multi-component" || { echo "expected rationale text: $OUT"; exit 1; }
echo "02-mocked-haiku: OK"
