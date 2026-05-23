#!/usr/bin/env bash
# Test 01: discovery basic — fixture has 4 plugin entries (alpha, beta×2, orphan, gamma).
# After dedupe by installPath and orphan filter: expect 3 records (alpha, beta, gamma).
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$(mktemp -d -t update-plugins-test-XXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# Create the install dirs the fixture references (alpha, beta, gamma — NOT orphan)
mkdir -p "$FIXTURE_DIR/cache/alpha" "$FIXTURE_DIR/cache/beta" "$FIXTURE_DIR/cache/gamma"

# Substitute FIXTURE_DIR placeholder in fixture
INSTALLED_JSON="$FIXTURE_DIR/installed_plugins.json"
sed "s|FIXTURE_DIR|$FIXTURE_DIR|g" "$SCRIPT_DIR/fixtures/installed_plugins.fixture.json" > "$INSTALLED_JSON"

# Run analyzer in --discovery-only mode (debug verb that prints JSON list to stdout)
export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"
result=$(python3 ~/.claude/scripts/update-plugins.py --discovery-only 2>/dev/null)

# Expect exactly 3 records (alpha, beta deduped to 1, gamma; orphan filtered)
count=$(printf '%s' "$result" | python3 -c 'import sys, json; print(len(json.loads(sys.stdin.read())))')

if [ "$count" -ne 3 ]; then
    echo "Expected 3 records, got $count" >&2
    printf '%s\n' "$result" >&2
    exit 1
fi

# Verify orphan is NOT in the list
if printf '%s' "$result" | grep -q 'orphan@marketplace-c'; then
    echo "Orphan record should have been filtered" >&2
    exit 1
fi

# Verify beta appears exactly once (dedupe)
beta_count=$(printf '%s' "$result" | grep -c 'beta@marketplace-b')
if [ "$beta_count" -ne 1 ]; then
    echo "Expected beta to appear once after dedupe, got $beta_count" >&2
    exit 1
fi

exit 0
