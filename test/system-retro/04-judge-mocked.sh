#!/bin/bash
# judge_session round-trip with a mocked `claude` binary that emits the envelope shape.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Mock claude: emit a JSON envelope whose .result is a JSON string matching the schema.
cat > "$TMP/claude" <<'EOF'
#!/bin/bash
INNER='{"shipped_and_smoked":4,"incremental_value":3,"mode_fit":5,"time_to_done_vs_scope":2,"primary_gap":"smoke evidence weak","process_pattern":"shipped-no-smoke"}'
printf '{"type":"result","result":%s,"model":"haiku"}\n' "$(echo "$INNER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
EOF
chmod +x "$TMP/claude"

export SYSTEM_RETRO_CLAUDE_CMD="$TMP/claude"

python3 <<PY
import importlib.util, os
spec = importlib.util.spec_from_file_location("sr", "$HOME/.claude/scripts/system-retro.py")
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)

s = sr.SessionSummary(
    session_id="testsid", project_slug="-fake", cwd_guess=None, transcript_path="/x",
    start_ts=None, end_ts=None, duration_min=1.0,
    user_msg_count=1, assistant_msg_count=1, tool_call_count=0, subagent_count=0,
    first_user_msg="do the thing", last_user_msg="done?", last_assistant_msg="done",
    mode_counts={"ship":1}, superpowers_used=[], dominant_mode="ship",
    smoke_evidence_hits=0,
)
v = sr.judge_session(s)
assert v is not None, "expected verdict from mocked claude"
assert v["shipped_and_smoked"] == 4, v
assert v["process_pattern"] == "shipped-no-smoke", v
assert v["session_id"] == "testsid", "session_id should be attached"
print("04-judge-mocked: OK")
PY
