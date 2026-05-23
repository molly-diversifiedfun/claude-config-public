#!/bin/bash
# SYSTEM_RETRO_NO_JUDGE=1 produces a report without spending any Haiku tokens.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PROJ="$TMP/projects/-Users-fake-github-x"
mkdir -p "$PROJ"
cat > "$PROJ/sid.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-05-23T07:00:00Z","message":{"role":"user","content":"/build a thing"}}
{"type":"assistant","timestamp":"2026-05-23T07:30:00Z","message":{"role":"assistant","content":"ok"}}
EOF

export SYSTEM_RETRO_PROJECTS_DIR="$TMP/projects"
export SYSTEM_RETRO_REPORT_DIR="$TMP/reports"
export SYSTEM_RETRO_NO_JUDGE=1
# Empty fixtures so joins are no-ops
export SYSTEM_RETRO_HOOK_BLOCKS="$TMP/none.log"
export SYSTEM_RETRO_AGENT_EVAL="$TMP/none.jsonl"

OUT_PATH=$(python3 ~/.claude/scripts/system-retro.py 2>/dev/null | tail -1)
test -f "$OUT_PATH" || { echo "expected report file at $OUT_PATH"; exit 1; }
grep -q "DISABLED (extraction-only)" "$OUT_PATH" || { echo "expected judge-disabled banner"; cat "$OUT_PATH"; exit 1; }
grep -q "Raw session table" "$OUT_PATH" || { echo "expected raw table"; exit 1; }
echo "07-extraction-only-mode: OK"
