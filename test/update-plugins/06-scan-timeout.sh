#!/usr/bin/env bash
# Test 06: git-mock ls-remote sleeps 3s; analyzer per-call timeout is 1s → SKIPPED:timeout.
# Uses inline scenario file with 3000ms sleep + PLUGIN_UPDATE_PER_CALL_TIMEOUT=1 for fast test runtime.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$(mktemp -d -t update-plugins-test-XXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

mkdir -p "$FIXTURE_DIR/cache/alpha"

INSTALLED_JSON="$FIXTURE_DIR/installed_plugins.json"
cat > "$INSTALLED_JSON" <<EOF
{
  "version": 2,
  "plugins": {
    "alpha@marketplace-a": [
      {
        "scope": "user",
        "installPath": "$FIXTURE_DIR/cache/alpha",
        "version": "1.0.0",
        "gitCommitSha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }
    ]
  }
}
EOF

# Use a shortened-sleep scenario for fast tests
cat > "$FIXTURE_DIR/06-timeout.txt" <<EOF
remote get-url origin|https://example.invalid/alpha.git||0|0
ls-remote origin HEAD|never-printed||0|3000
EOF

export PATH="$SCRIPT_DIR/fixtures/git-mock:$PATH"
export GIT_MOCK_SCENARIO="$FIXTURE_DIR/06-timeout.txt"
export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"
export PLUGIN_UPDATE_PER_CALL_TIMEOUT=1   # 1-second per-call timeout for fast test

result=$(python3 ~/.claude/scripts/update-plugins.py 2>/dev/null | tail -n 1)
drifted=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["drifted"])')

if [ "$drifted" -ne 0 ]; then
    echo "Expected drifted=0 (SKIPPED:timeout), got $drifted" >&2
    exit 1
fi

report=$(ls -t "$FIXTURE_DIR/reports"/*.md 2>/dev/null | head -n 1)
if [ -z "$report" ] || ! grep -q "timeout" "$report"; then
    echo "Expected report to contain 'timeout'; report=$report" >&2
    [ -n "$report" ] && cat "$report" >&2
    exit 1
fi

exit 0
