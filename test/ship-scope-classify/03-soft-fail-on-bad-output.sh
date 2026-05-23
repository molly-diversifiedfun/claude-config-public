#!/bin/bash
# Mocked claude returns garbage; classifier soft-fails to S with clear rationale.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/claude" <<'EOF'
#!/bin/bash
echo "this is not JSON at all and has no braces anywhere whatsoever"
EOF
chmod +x "$TMP/claude"

OUT=$(SHIP_SCOPE_CLAUDE_CMD="$TMP/claude" python3 ~/.claude/scripts/ship-scope-classify.py "do a thing")
echo "$OUT" | grep -q '"scope": "S"' || { echo "expected S fallback: $OUT"; exit 1; }
echo "$OUT" | grep -qi "no-json\|parse" || { echo "expected fallback rationale: $OUT"; exit 1; }
echo "03-soft-fail-on-bad-output: OK"
