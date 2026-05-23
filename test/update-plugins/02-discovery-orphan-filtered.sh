#!/usr/bin/env bash
# Test 02: orphan filtered — fixture references installPath that doesn't exist; record dropped.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$(mktemp -d -t update-plugins-test-XXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# Deliberately do NOT create the orphan installPath
mkdir -p "$FIXTURE_DIR/cache/alpha" "$FIXTURE_DIR/cache/beta" "$FIXTURE_DIR/cache/gamma"

INSTALLED_JSON="$FIXTURE_DIR/installed_plugins.json"
sed "s|FIXTURE_DIR|$FIXTURE_DIR|g" "$SCRIPT_DIR/fixtures/installed_plugins.fixture.json" > "$INSTALLED_JSON"

export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"

# Run analyzer with --discovery-only AND --emit-orphan-count
result=$(python3 ~/.claude/scripts/update-plugins.py --discovery-only --emit-orphan-count 2>/dev/null)
orphan_count=$(printf '%s' "$result" | python3 -c 'import sys, json; d = json.loads(sys.stdin.read()); print(d["orphan_count"])')

if [ "$orphan_count" -ne 1 ]; then
    echo "Expected 1 orphan filtered, got $orphan_count" >&2
    exit 1
fi

exit 0
