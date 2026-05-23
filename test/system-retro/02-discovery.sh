#!/bin/bash
# discover_recent_sessions filters agent-*.jsonl and zero-byte files; orders by mtime.
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

PROJ="$TMP/-Users-fake-github-x"
mkdir -p "$PROJ"

# 3 valid (padded above MIN_SESSION_BYTES) + 1 agent-* (excluded) + 1 zero-byte (excluded) + 1 metadata-only (excluded by min-size)
PAD=$(python3 -c "print('x'*5000)")
for i in 1 2 3; do
  printf '{"type":"user","timestamp":"2026-05-23T07:00:00Z","message":{"role":"user","content":"%s"}}\n' "$PAD" > "$PROJ/sess-$i.jsonl"
  touch -t 2026052307$((10+i)) "$PROJ/sess-$i.jsonl"
done
printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$PAD" > "$PROJ/agent-foo.jsonl"
touch "$PROJ/empty.jsonl"
# Metadata-only: small, below min_bytes
echo '{"type":"ai-title","aiTitle":"x"}' > "$PROJ/meta-only.jsonl"
touch -t 202605230800 "$PROJ/meta-only.jsonl"

python3 <<PY
import importlib.util
spec = importlib.util.spec_from_file_location("sr", "$HOME/.claude/scripts/system-retro.py")
sr = importlib.util.module_from_spec(spec); import sys as _s; _s.modules["sr"] = sr; spec.loader.exec_module(sr)
from pathlib import Path

paths = sr.discover_recent_sessions(Path("$TMP"), 5)
names = [p.name for p in paths]
assert "agent-foo.jsonl" not in names, "agent-* should be excluded"
assert "empty.jsonl" not in names, "zero-byte should be excluded"
assert "meta-only.jsonl" not in names, "metadata-only (below min_bytes) should be excluded"
assert len(paths) == 3, f"expected 3, got {len(paths)}: {names}"
# Most-recent first
assert names[0] == "sess-3.jsonl", f"expected sess-3 first, got {names[0]}"
print("02-discovery: OK")
PY
