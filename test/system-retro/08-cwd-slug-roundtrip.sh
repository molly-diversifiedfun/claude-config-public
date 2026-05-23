#!/bin/bash
# _slug_to_cwd resolves real paths by forward-built index (slug encoding is lossy:
# both '/' and '.' map to '-', so reverse-parsing alone fails on `user.name`).
set -e

python3 <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("sr", os.path.expanduser("~/.claude/scripts/system-retro.py"))
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)
from pathlib import Path

# Forward encoding must produce no leading double-dash for absolute paths.
slug = sr._path_to_slug(Path("$HOME/github/<your-bot>"))
assert slug == "<your-workspace>-<your-bot>", f"encoding wrong: {slug!r}"

# Round-trip: real existing dir's slug must resolve back to itself
home = Path.home()
test_dir = home / "github"
if test_dir.exists():
    s = sr._path_to_slug(test_dir)
    resolved = sr._slug_to_cwd(s)
    assert resolved == str(test_dir), f"{s} -> {resolved} (expected {test_dir})"

# Non-matching slug returns None (not garbage)
assert sr._slug_to_cwd("-nonexistent-fake-dir-xyz999") is None

print("08-cwd-slug-roundtrip: OK")
PY
