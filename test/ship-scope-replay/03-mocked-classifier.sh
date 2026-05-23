#!/bin/bash
# End-to-end: discover 2 fake sessions, classify via mocked classifier, render markdown report.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Fake transcripts in fake projects dir
PROJ="$TMP/projects/-proj-x"
mkdir -p "$PROJ"
PAD=$(python3 -c "print('x'*5000)")
cat > "$PROJ/sess-a.jsonl" <<EOF
{"type":"user","timestamp":"2026-05-23T07:00:00Z","message":{"role":"user","content":"add slack auth to the landing page"}}
{"type":"assistant","timestamp":"2026-05-23T07:30:00Z","message":{"role":"assistant","content":[{"type":"text","text":"$PAD"}]}}
EOF
cat > "$PROJ/sess-b.jsonl" <<EOF
{"type":"user","timestamp":"2026-05-23T08:00:00Z","message":{"role":"user","content":"Context: This summary will be shown in a list"}}
{"type":"assistant","timestamp":"2026-05-23T08:01:00Z","message":{"role":"assistant","content":[{"type":"text","text":"$PAD"}]}}
EOF

# Mock classifier: ignores input, always returns scope=M
cat > "$TMP/fake-classifier.py" <<'EOF'
#!/usr/bin/env python3
import sys, json
print(json.dumps({"scope":"M","rationale":"mocked"}))
EOF
chmod +x "$TMP/fake-classifier.py"

export SHIP_SCOPE_REPLAY_PROJECTS_DIR="$TMP/projects"
export SHIP_SCOPE_REPLAY_CLASSIFIER="$TMP/fake-classifier.py"
export SHIP_SCOPE_REPLAY_REPORT_DIR="$TMP/reports"

OUT_PATH=$(python3 ~/.claude/scripts/ship-scope-replay.py 5 2>/dev/null | tail -1)
test -f "$OUT_PATH" || { echo "expected report: $OUT_PATH"; exit 1; }

# sess-a has a real ask → classified. sess-b has auto-summary → skipped.
grep -q "add slack auth" "$OUT_PATH" || { echo "FAIL — sess-a ask should appear: $(cat $OUT_PATH)"; exit 1; }
grep -q "Context: This summary" "$OUT_PATH" && { echo "FAIL — sess-b should have been filtered"; exit 1; }

# Distribution table should show M=1 (only sess-a classified)
grep -qE '\| \*\*M\*\* \| 1 \|' "$OUT_PATH" || { echo "FAIL — expected M=1 in distribution; got:"; cat "$OUT_PATH"; exit 1; }

# Sessions discovered=2 but classified=1
grep -q "discovered:\*\* 2" "$OUT_PATH" || { echo "FAIL — expected discovered=2"; cat "$OUT_PATH"; exit 1; }
grep -q "classified:\*\* 1" "$OUT_PATH" || { echo "FAIL — expected classified=1"; cat "$OUT_PATH"; exit 1; }

echo "03-mocked-classifier: OK"
