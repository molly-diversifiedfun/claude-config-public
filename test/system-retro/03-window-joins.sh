#!/bin/bash
# Hook-blocks + agent-eval window filtering: entries inside window kept, outside dropped.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BLOCKS="$TMP/hook-blocks.log"
EVALS="$TMP/agent-eval.jsonl"

cat > "$BLOCKS" <<'EOF'
{"timestamp":"2026-05-22T10:00:00Z","hook":"early","cwd":"/x","reason":"before window"}
{"timestamp":"2026-05-23T07:15:00Z","hook":"in1","cwd":"/x","reason":"inside"}
{"timestamp":"2026-05-23T07:20:00Z","hook":"in2","cwd":"/other","reason":"wrong cwd"}
{"timestamp":"2026-05-23T09:00:00Z","hook":"late","cwd":"/x","reason":"after window"}
EOF

cat > "$EVALS" <<'EOF'
{"judged_at":"2026-05-22T10:00:00Z","used_injected_skill":true,"which_skill":"foo","quality_score":4}
{"judged_at":"2026-05-23T07:18:00Z","used_injected_skill":false,"which_skill":"bar","quality_score":2}
{"judged_at":"2026-05-23T09:00:00Z","used_injected_skill":true,"which_skill":"baz","quality_score":5}
EOF

python3 <<PY
import importlib.util
spec = importlib.util.spec_from_file_location("sr", "$HOME/.claude/scripts/system-retro.py")
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)
from pathlib import Path

start, end = "2026-05-23T07:00:00Z", "2026-05-23T08:00:00Z"
blocks = sr.join_hook_blocks(Path("$BLOCKS"), start, end, "/x")
assert len(blocks) == 1, f"expected 1 block in window+cwd, got {len(blocks)}: {blocks}"
assert blocks[0]["hook"] == "in1"

# Without cwd filter, two should be in window
all_blocks = sr.join_hook_blocks(Path("$BLOCKS"), start, end, None)
assert len(all_blocks) == 2, f"expected 2 blocks ignoring cwd, got {len(all_blocks)}"

evals = sr.join_agent_evals(Path("$EVALS"), start, end)
assert len(evals) == 1, f"expected 1 eval in window, got {len(evals)}"
assert evals[0]["which_skill"] == "bar"
print("03-window-joins: OK")
PY
