#!/usr/bin/env bash
# Test 08: zero plugins → drifted=0, report still written, no apply prompt content.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$(mktemp -d -t update-plugins-test-XXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

INSTALLED_JSON="$FIXTURE_DIR/installed_plugins.json"
cat > "$INSTALLED_JSON" <<'EOF'
{
  "version": 2,
  "plugins": {}
}
EOF

export PLUGIN_UPDATE_INSTALLED_JSON="$INSTALLED_JSON"
export PLUGIN_UPDATE_REPORT_DIR="$FIXTURE_DIR/reports"

result=$(python3 ~/.claude/scripts/update-plugins.py 2>/dev/null | tail -n 1)
drifted=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["drifted"])')
drifted_list_len=$(printf '%s' "$result" | python3 -c 'import sys, json; print(len(json.load(sys.stdin)["drifted_list"]))')

if [ "$drifted" -ne 0 ] || [ "$drifted_list_len" -ne 0 ]; then
    echo "Expected drifted=0 + empty list, got drifted=$drifted list_len=$drifted_list_len" >&2
    exit 1
fi

# Report should still be written
report=$(printf '%s' "$result" | python3 -c 'import sys, json; print(json.load(sys.stdin)["report_path"])')
if [ ! -f "$report" ]; then
    echo "Expected report written even for empty corpus" >&2
    exit 1
fi

exit 0
