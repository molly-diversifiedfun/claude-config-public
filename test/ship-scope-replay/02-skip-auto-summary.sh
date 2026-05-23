#!/bin/bash
# Sessions whose first user prompt is auto-summary / hook-feedback / caveat should be skipped.
set -e

python3 <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("sr", os.path.expanduser("~/.claude/scripts/ship-scope-replay.py"))
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)

# Direct function tests on _is_real_ask
assert sr._is_real_ask("how do we evaluate whether my systems are working?") is True
assert sr._is_real_ask("Context: This summary will be shown in a list...") is False
assert sr._is_real_ask("Stop hook feedback: DoD INCOMPLETE...") is False
assert sr._is_real_ask("<local-command-caveat>Caveat: ...</local-command-caveat>") is False
assert sr._is_real_ask("") is False
assert sr._is_real_ask("hi") is False  # too short
assert sr._is_real_ask("lets do step 5 build") is True  # short but real
print("02-skip-auto-summary: OK")
PY
