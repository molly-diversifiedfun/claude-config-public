#!/usr/bin/env bash
# Test 05: git-mock ls-remote exits 128 → SKIPPED:unreachable; drifted=0.
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

export PATH="$SCRIPT_DIR/fixtures/git-mock:$PATH"
export GIT_MOCK_SCENARIO="$SCRIPT_DIR/fixtures/scenarios/05-unreachable.txt"
export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"

result=$(python3 ~/.claude/scripts/update-plugins.py 2>/dev/null | tail -n 1)
drifted=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["drifted"])')

if [ "$drifted" -ne 0 ]; then
    echo "Expected drifted=0 (SKIPPED:unreachable counts as not-drifted), got $drifted" >&2
    echo "Full result: $result" >&2
    exit 1
fi

# Report should mention the SKIPPED section with reason "unreachable"
report=$(ls -t "$FIXTURE_DIR/reports"/*.md 2>/dev/null | head -n 1)
if [ -z "$report" ] || ! grep -q "unreachable" "$report"; then
    echo "Expected report to contain 'unreachable'; report=$report" >&2
    [ -n "$report" ] && cat "$report" >&2
    exit 1
fi

exit 0
