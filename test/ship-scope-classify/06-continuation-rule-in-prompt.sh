#!/bin/bash
# Structural regression: the prompt template MUST include the continuation rule
# (defaults vague "step N" / "continue from before" asks to M instead of S).
# Pure prompt-engineering calibrations can't be unit-tested via Haiku call
# (slow + costly + nondeterministic). This test verifies the rule is in the
# template by capturing the exact prompt the mock receives.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Mock claude that echoes its positional prompt arg to a capture file
cat > "$TMP/claude" <<'EOF'
#!/bin/bash
# Capture the prompt (last positional arg) for inspection
while [ "$#" -gt 1 ]; do shift; done
echo "$1" > "$CAPTURE_FILE"
# Return a valid JSON envelope so the script doesn't soft-fail
printf '{"type":"result","result":"{\\"scope\\":\\"M\\",\\"rationale\\":\\"test\\"}"}\n'
EOF
chmod +x "$TMP/claude"

export SHIP_SCOPE_CLAUDE_CMD="$TMP/claude"
export CAPTURE_FILE="$TMP/captured-prompt.txt"

python3 ~/.claude/scripts/ship-scope-classify.py "lets do step 5 build" > /dev/null

# Verify the prompt sent to claude contained the CONTINUATION RULE marker
grep -q "CONTINUATION RULE" "$CAPTURE_FILE" || { echo "06-continuation-rule-in-prompt: FAIL — CONTINUATION RULE missing from prompt"; head -50 "$CAPTURE_FILE"; exit 1; }
grep -q "step N" "$CAPTURE_FILE" || { echo "06-continuation-rule-in-prompt: FAIL — 'step N' guidance missing"; exit 1; }
grep -q "DEFAULT TO M" "$CAPTURE_FILE" || { echo "06-continuation-rule-in-prompt: FAIL — 'DEFAULT TO M' missing"; exit 1; }
echo "06-continuation-rule-in-prompt: OK"
