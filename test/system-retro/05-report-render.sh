#!/bin/bash
# render_report produces a markdown doc with per-mode table, exemplars, raw table.
set -e

python3 <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("sr", os.path.expanduser("~/.claude/scripts/system-retro.py"))
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)

def mk(sid, mode, dur=10):
    return sr.SessionSummary(
        session_id=sid, project_slug=f"-proj-{sid}", cwd_guess=None,
        transcript_path="/x", start_ts=None, end_ts=None, duration_min=dur,
        user_msg_count=3, assistant_msg_count=5, tool_call_count=4, subagent_count=1,
        first_user_msg=f"do {sid}", last_user_msg="end", last_assistant_msg="done",
        mode_counts={mode:1}, superpowers_used=[], dominant_mode=mode,
        smoke_evidence_hits=0,
    )

summaries = [mk("aaaa1111", "ship"), mk("bbbb2222", "build"), mk("cccc3333", "ship")]
verdicts = [
    {"session_id":"aaaa1111","shipped_and_smoked":5,"incremental_value":5,"mode_fit":5,"time_to_done_vs_scope":5,"primary_gap":"none","process_pattern":"shipped-clean"},
    {"session_id":"bbbb2222","shipped_and_smoked":2,"incremental_value":3,"mode_fit":4,"time_to_done_vs_scope":2,"primary_gap":"scope drift","process_pattern":"shipped-scope-creep"},
    {"session_id":"cccc3333","shipped_and_smoked":1,"incremental_value":1,"mode_fit":2,"time_to_done_vs_scope":1,"primary_gap":"stuck","process_pattern":"stuck-mid-impl"},
]

md = sr.render_report(summaries, verdicts, "synthesis text here", used_judge=True)
assert "# System Retrospective" in md
assert "Per-mode aggregates" in md
assert "Process patterns observed" in md
assert "Exemplars" in md
assert "Anti-exemplars" in md
assert "Cross-cutting themes" in md
assert "synthesis text here" in md
assert "Raw session table" in md
# Top exemplar should be aaaa1111 (combined=20)
top_idx = md.find("Exemplars")
bot_idx = md.find("Anti-exemplars")
assert "aaaa1111" in md[top_idx:bot_idx], "aaaa1111 should be in exemplars section"
assert "cccc3333" in md[bot_idx:], "cccc3333 should be in anti-exemplars section"
print("05-report-render: OK")
PY
