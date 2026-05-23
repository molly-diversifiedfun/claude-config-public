#!/usr/bin/env bash
# Test 07: mixed bucket (1 DRIFTED, 1 CURRENT, 1 SKIPPED) → report has all three sections.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$(mktemp -d -t update-plugins-test-XXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

mkdir -p "$FIXTURE_DIR/cache/alpha" "$FIXTURE_DIR/cache/beta" "$FIXTURE_DIR/cache/gamma"

INSTALLED_JSON="$FIXTURE_DIR/installed_plugins.json"
cat > "$INSTALLED_JSON" <<EOF
{
  "version": 2,
  "plugins": {
    "alpha@marketplace-a": [
      {"scope":"user","installPath":"$FIXTURE_DIR/cache/alpha","version":"1.0.0","gitCommitSha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
    ],
    "beta@marketplace-b": [
      {"scope":"user","installPath":"$FIXTURE_DIR/cache/beta","version":"2.0.0","gitCommitSha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}
    ],
    "gamma@marketplace-d": [
      {"scope":"user","installPath":"$FIXTURE_DIR/cache/gamma","version":"1.0.0","gitCommitSha":"dddddddddddddddddddddddddddddddddddddddd"}
    ]
  }
}
EOF

export PATH="$SCRIPT_DIR/fixtures/git-mock:$PATH"
export GIT_MOCK_SCENARIO="$SCRIPT_DIR/fixtures/scenarios/07-mixed.txt"
export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"

result=$(python3 ~/.claude/scripts/update-plugins.py 2>/dev/null | tail -n 1)
report=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["report_path"])')

if [ -z "$report" ] || [ ! -f "$report" ]; then
    echo "Report not written. Result: $result" >&2
    exit 1
fi

for section in "## DRIFTED" "## CURRENT" "## SKIPPED"; do
    if ! grep -q "$section" "$report"; then
        echo "Missing section: $section" >&2
        cat "$report" >&2
        exit 1
    fi
done

# Verify the DRIFTED row has the copy-paste command
if ! grep -q 'claude plugin update alpha@marketplace-a' "$report"; then
    echo "DRIFTED row missing 'claude plugin update' command" >&2
    cat "$report" >&2
    exit 1
fi

# Verify drifted count
drifted=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["drifted"])')
if [ "$drifted" -ne 1 ]; then
    echo "Expected drifted=1, got $drifted" >&2
    exit 1
fi

exit 0
