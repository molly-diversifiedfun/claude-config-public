#!/usr/bin/env bash
# Test 03: git-mock returns remote SHA different from installed → DRIFTED bucket populated.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$(mktemp -d -t update-plugins-test-XXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

mkdir -p "$FIXTURE_DIR/cache/alpha"

# Minimal single-plugin fixture (alpha at SHA aaaa...)
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

# Wire git-mock onto PATH; scenario 03 returns remote SHA ffff... (≠ installed aaaa...)
export PATH="$SCRIPT_DIR/fixtures/git-mock:$PATH"
export GIT_MOCK_SCENARIO="$SCRIPT_DIR/fixtures/scenarios/03-drift.txt"

export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"

result=$(python3 ~/.claude/scripts/update-plugins.py 2>/dev/null | tail -n 1)
drifted=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["drifted"])')

if [ "$drifted" -ne 1 ]; then
    echo "Expected drifted=1, got $drifted" >&2
    echo "Full result: $result" >&2
    exit 1
fi

exit 0
