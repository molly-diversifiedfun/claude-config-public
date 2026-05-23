#!/bin/bash
# Aggregate floor: tiny abandoned sessions (dur < MIN_AGG_DURATION_MIN OR
# tools < MIN_AGG_TOOL_CALLS) are excluded from per-mode averages but stay
# in the raw session table.
set -e

python3 <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("sr", os.path.expanduser("~/.claude/scripts/system-retro.py"))
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)

# Helper
def mk(sid, mode, dur, tools):
    return sr.SessionSummary(
        session_id=sid, project_slug=f"-proj-{sid}", cwd_guess=None,
        transcript_path="/x", start_ts=None, end_ts=None, duration_min=dur,
        user_msg_count=3, assistant_msg_count=5, tool_call_count=tools, subagent_count=0,
        first_user_msg=f"do {sid}", last_user_msg="end", last_assistant_msg="done",
        mode_counts={mode:1}, superpowers_used=[], dominant_mode=mode,
        smoke_evidence_hits=0,
    )

summaries = [
    mk("realraw1", "raw", 30, 50),     # passes floor
    mk("realraw2", "raw", 20, 40),     # passes floor
    mk("abandoned1", "raw", 0.5, 0),   # excluded — too short, no tools
    mk("abandoned2", "raw", 0.1, 1),   # excluded — too short
    mk("shortbut", "raw", 60, 3),      # excluded — too few tools
    mk("shipgood", "ship", 60, 80),    # passes floor
]
verdicts = [
    {"session_id": s.session_id, "shipped_and_smoked": 5, "incremental_value": 5, "mode_fit": 5, "time_to_done_vs_scope": 5, "primary_gap": "", "process_pattern": "shipped-clean"}
    for s in summaries[:2] + [summaries[5]]
] + [
    # tiny abandoned ones get score=1 (typical for stuck-mid-impl)
    {"session_id": s.session_id, "shipped_and_smoked": 1, "incremental_value": 1, "mode_fit": 1, "time_to_done_vs_scope": 1, "primary_gap": "stuck", "process_pattern": "abandoned"}
    for s in summaries[2:5]
]

# Floor check direct
assert sr._passes_aggregate_floor(summaries[0]) is True, "30min+50tools should pass"
assert sr._passes_aggregate_floor(summaries[2]) is False, "0.5min+0tools should fail"
assert sr._passes_aggregate_floor(summaries[4]) is False, "60min+3tools should fail (tools below floor)"

md = sr.render_report(summaries, verdicts, "synth", used_judge=True)

# Aggregate table should reflect ONLY the 3 floor-passing sessions
# (2 raw avg 5.0, 1 ship avg 5.0). If the 3 abandoned were included, raw avg would be ~2.6 not 5.0.
assert "| raw | 2 | 5.0 |" in md, f"raw aggregate should be n=2 avg 5.0; got: {[l for l in md.split(chr(10)) if 'raw' in l][:3]}"
assert "| ship | 1 | 5.0 |" in md, "ship aggregate should be n=1 avg 5.0"

# Raw table at the bottom should STILL show all 6 sessions
for sid in ("realraw1", "abandoned1", "shortbut"):
    assert sid[:8] in md, f"{sid} should appear in raw table"

# Floor banner should mention exclusion count
assert "3/6 excluded" in md, "banner should report 3 excluded of 6"

print("09-aggregate-floor: OK")
PY
