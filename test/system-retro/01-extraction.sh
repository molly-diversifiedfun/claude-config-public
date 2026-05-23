#!/bin/bash
# Verify extract_session pulls correct fields from a synthetic transcript.
set -e
cd "$(dirname "$0")"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PROJ="$TMP/projects/-Users-fake-github-myproj"
mkdir -p "$PROJ"
SID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

cat > "$PROJ/$SID.jsonl" <<'EOF'
{"type":"last-prompt","sessionId":"x"}
{"type":"user","timestamp":"2026-05-23T07:00:00Z","message":{"role":"user","content":"please /ship the new auth feature using superpowers:test-driven-development"}}
{"type":"assistant","timestamp":"2026-05-23T07:01:00Z","message":{"role":"assistant","content":[{"type":"text","text":"OK starting"},{"type":"tool_use","name":"Read","input":{}}]}}
{"type":"assistant","timestamp":"2026-05-23T07:02:00Z","message":{"role":"assistant","content":[{"type":"tool_use","name":"Agent","input":{}}]}}
{"type":"user","timestamp":"2026-05-23T07:30:00Z","message":{"role":"user","content":"verified — landed in prod, smoke confirms"}}
{"type":"assistant","timestamp":"2026-05-23T07:31:00Z","message":{"role":"assistant","content":"done"}}
EOF

python3 <<PY
import sys
sys.path.insert(0, "$HOME/.claude/scripts")
import importlib.util
spec = importlib.util.spec_from_file_location("sr", "$HOME/.claude/scripts/system-retro.py")
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)
from pathlib import Path

s = sr.extract_session(Path("$PROJ/$SID.jsonl"))
assert s is not None, "expected SessionSummary"
assert s.session_id == "$SID", f"sid mismatch: {s.session_id}"
assert s.user_msg_count == 2, f"user_msg_count={s.user_msg_count}"
assert s.assistant_msg_count == 3, f"asst_msg_count={s.assistant_msg_count}"
assert s.tool_call_count == 2, f"tool_call_count={s.tool_call_count}"
assert s.subagent_count == 1, f"subagent_count={s.subagent_count}"
assert s.mode_counts["ship"] == 1, f"ship={s.mode_counts['ship']}"
assert "superpowers:test-driven-development" in s.superpowers_used
assert s.dominant_mode == "ship"
assert s.smoke_evidence_hits >= 1, "expected smoke evidence hit"
assert s.duration_min and s.duration_min > 30, f"duration={s.duration_min}"
print("01-extraction: OK")
PY
